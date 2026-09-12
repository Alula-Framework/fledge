import FlightCore
import FlightWeb
import Foundation
import HTTPTypes

extension HTTPField.Name {
    /// The lease id every call after `/lease` must present — a fixed,
    /// known-valid literal, so the force-unwrap here can never fail.
    static let leaseID = HTTPField.Name("X-Lease-Id")!
    /// This session's own Postgres connection string (PLAN §3's `db`
    /// tier), set once at `/lease` time — absent entirely for a
    /// `snippet`-tier session. A header, not a JSON body, so `/lease`
    /// keeps working with no body at all for the common no-database case,
    /// and so the connection string (which may itself contain characters
    /// a JSON-body macro's Decodable binding would need to escape) never
    /// needs any encoding beyond what an HTTP header value already allows.
    static let databaseURL = HTTPField.Name("X-Database-Url")!
}

struct WriteRequest: Decodable {
    let content: String
}

/// The runner's internal control API (PLAN §4): one workspace, leased to
/// at most one session at a time. Every route but `/lease` requires the
/// lease id it returned, checked against `state` — a stale id from a
/// previous session, or a guess, is rejected, never just "present."
@Controller
struct RunnerController {
    // flight:hand-registered — provided by AppModule (matched by type),
    // since it's a plain actor, never scanned as a @Component.
    @Inject var state: WorkspaceState
    @ConfigValue("workspace.live", default: "/workspace") var liveWorkspacePath: String
    @ConfigValue("workspace.pristine", default: "/workspace-pristine") var pristineWorkspacePath: String

    private var liveWorkspace: URL { URL(fileURLWithPath: liveWorkspacePath) }
    private var pristineWorkspace: URL { URL(fileURLWithPath: pristineWorkspacePath) }

    /// The one file a session is ever allowed to change.
    private var exerciseFile: URL {
        liveWorkspace.appending(path: "Sources/exercise/main.swift")
    }

    private static let maxContentBytes = 32 * 1024

    @PostRoute("/lease")
    func lease(_ context: RequestContext) async -> Response {
        guard let id = await state.lease(databaseURL: context.request.headers[.databaseURL]) else {
            return .problem(status: .conflict, message: "already leased")
        }
        return (try? Response.json(["leaseId": id], status: .created)) ?? .status(.internalServerError)
    }

    @PostRoute("/write")
    func write(_ context: RequestContext, body: WriteRequest) async throws -> Response {
        guard await isLeaseValid(context) else {
            return .problem(status: .forbidden, message: "no valid lease")
        }
        guard body.content.utf8.count <= Self.maxContentBytes else {
            return .problem(status: .contentTooLarge, message: "content exceeds \(Self.maxContentBytes) bytes")
        }
        try Data(body.content.utf8).write(to: exerciseFile, options: .atomic)
        return .noContent
    }

    @PostRoute("/run")
    func run(_ context: RequestContext) async -> Response {
        guard await isLeaseValid(context) else {
            return .problem(status: .forbidden, message: "no valid lease")
        }
        let workspace = liveWorkspace
        let databaseURL = await state.databaseURL
        return .serverSentEvents { events in
            for await event in ProcessRunner.run(in: workspace, databaseURL: databaseURL) {
                guard await events.send(data: Self.encode(event), event: Self.name(event)) else { return }
            }
        }
    }

    @PostRoute("/reset")
    func reset(_ context: RequestContext) async throws -> Response {
        guard await isLeaseValid(context) else {
            return .problem(status: .forbidden, message: "no valid lease")
        }
        await state.killRunning()
        try restorePristine()
        return .noContent
    }

    @PostRoute("/release")
    func release(_ context: RequestContext) async throws -> Response {
        guard await isLeaseValid(context) else {
            return .problem(status: .forbidden, message: "no valid lease")
        }
        await state.release()
        try restorePristine()
        return .noContent
    }

    private func isLeaseValid(_ context: RequestContext) async -> Bool {
        guard let candidate = context.request.headers[.leaseID] else { return false }
        return await state.isValid(candidate)
    }

    private func restorePristine() throws {
        let source = pristineWorkspace.appending(path: "Sources/exercise/main.swift")
        let data = try Data(contentsOf: source)
        try data.write(to: exerciseFile, options: .atomic)
    }

    private static func name(_ event: RunEvent) -> String {
        switch event {
        case .buildOutput: return "build_output"
        case .buildDone: return "build_done"
        case .runOutput: return "run_output"
        case .exited: return "exited"
        case .timedOut: return "timed_out"
        case .truncated: return "truncated"
        }
    }

    private static func encode(_ event: RunEvent) -> String {
        switch event {
        case .buildOutput(let line), .runOutput(let line):
            return line
        case .buildDone(let code), .exited(let code):
            return "\(code)"
        case .timedOut, .truncated:
            return ""
        }
    }
}
