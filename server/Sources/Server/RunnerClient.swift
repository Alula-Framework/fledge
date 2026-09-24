import AsyncHTTPClient
import Foundation
import NIOCore

/// Calls one runner supervisor's internal HTTP API — see
/// `runner/supervisor/Sources/Supervisor/RunnerController.swift` for the
/// authoritative contract this mirrors. Built against that code directly,
/// not PLAN.md's original sketch: there is no separate `GET /stream` route;
/// `POST /run` returns the SSE stream itself.
///
/// `HTTPClient.shared` (AsyncHTTPClient's process-wide client) is the one
/// real precedent for outbound HTTP calls in this codebase
/// (`AlulaSecurityCore/OIDC/JWKSSource.swift`) — Alula has no outbound
/// client wrapper of its own, so this follows that same convention rather
/// than inventing one.
struct RunnerClient: Sendable {
    enum RunnerClientError: Error, CustomStringConvertible {
        case unexpectedStatus(Int, String)
        case malformedResponse(String)

        var description: String {
            switch self {
            case .unexpectedStatus(let code, let context):
                return "runner returned \(code) for \(context)"
            case .malformedResponse(let context):
                return "runner response for \(context) did not match the expected shape"
            }
        }
    }

    private static let requestTimeout: TimeAmount = .seconds(10)
    // Longer than the runner's own 15s wall-clock build+run cap (see
    // ProcessRunner.wallClockLimit) so the runner is always the one that
    // times out first — a client-side timeout racing the server-side one
    // would leave the actual outcome ambiguous.
    private static let runTimeout: TimeAmount = .seconds(30)

    /// `databaseURL` is only present for a `db`-tier session (PLAN §3) —
    /// the runner stores it and hands it to every run's process
    /// environment as `DATABASE_URL`, but never needs it itself, which is
    /// why it travels as a header the runner just remembers rather than a
    /// JSON body `/lease` has to parse.
    func lease(baseURL: String, databaseURL: String? = nil) async throws -> String {
        var request = HTTPClientRequest(url: "\(baseURL)/lease")
        request.method = .POST
        if let databaseURL {
            request.headers.add(name: "X-Database-Url", value: databaseURL)
        }
        let response = try await HTTPClient.shared.execute(request, timeout: Self.requestTimeout)
        guard response.status == .created else {
            throw RunnerClientError.unexpectedStatus(Int(response.status.code), "/lease")
        }
        let body = try await response.body.collect(upTo: 1024 * 1024)
        struct LeaseResponse: Decodable { let leaseId: String }
        guard let decoded = try? JSONDecoder().decode(LeaseResponse.self, from: Data(buffer: body)) else {
            throw RunnerClientError.malformedResponse("/lease")
        }
        return decoded.leaseId
    }

    func write(baseURL: String, leaseID: String, content: String) async throws {
        var request = HTTPClientRequest(url: "\(baseURL)/write")
        request.method = .POST
        request.headers.add(name: "X-Lease-Id", value: leaseID)
        request.headers.add(name: "Content-Type", value: "application/json")
        request.body = .bytes(try JSONEncoder().encode(["content": content]))
        let response = try await HTTPClient.shared.execute(request, timeout: Self.requestTimeout)
        guard response.status == .noContent else {
            throw RunnerClientError.unexpectedStatus(Int(response.status.code), "/write")
        }
    }

    func reset(baseURL: String, leaseID: String) async throws {
        try await post(baseURL: baseURL, path: "/reset", leaseID: leaseID)
    }

    func release(baseURL: String, leaseID: String) async throws {
        try await post(baseURL: baseURL, path: "/release", leaseID: leaseID)
    }

    private func post(baseURL: String, path: String, leaseID: String) async throws {
        var request = HTTPClientRequest(url: "\(baseURL)\(path)")
        request.method = .POST
        request.headers.add(name: "X-Lease-Id", value: leaseID)
        let response = try await HTTPClient.shared.execute(request, timeout: Self.requestTimeout)
        guard response.status == .noContent else {
            throw RunnerClientError.unexpectedStatus(Int(response.status.code), path)
        }
    }

    /// Streams the runner's `/run` SSE response, calling `onEvent` with
    /// `(event name, data)` for each frame as it arrives. Parses WHATWG
    /// EventSource framing directly — `event:`/`data:` lines, multi-line
    /// data joined with "\n", a blank line ending a frame, lines starting
    /// with ":" ignored as comments/heartbeats — matching
    /// `ServerSentEvent.encoded` in AlulaWeb exactly, since that's what
    /// wrote it. No SSE-consuming helper exists anywhere in Alula to
    /// reuse (checked): this is a from-scratch client parser.
    func run(
        baseURL: String, leaseID: String,
        onEvent: @Sendable (_ event: String, _ data: String) async -> Void
    ) async throws {
        var request = HTTPClientRequest(url: "\(baseURL)/run")
        request.method = .POST
        request.headers.add(name: "X-Lease-Id", value: leaseID)
        let response = try await HTTPClient.shared.execute(request, timeout: Self.runTimeout)
        guard response.status == .ok else {
            throw RunnerClientError.unexpectedStatus(Int(response.status.code), "/run")
        }

        var pendingEvent: String?
        var pendingData: [String] = []
        var carry = ""

        func flush() async {
            defer { pendingEvent = nil; pendingData.removeAll() }
            guard let event = pendingEvent else { return }
            await onEvent(event, pendingData.joined(separator: "\n"))
        }

        for try await chunk in response.body {
            carry += String(buffer: chunk)
            while let newline = carry.firstIndex(of: "\n") {
                let line = String(carry[carry.startIndex..<newline])
                carry.removeSubrange(carry.startIndex...newline)
                if line.isEmpty {
                    await flush()
                } else if line.hasPrefix(":") {
                    continue
                } else if line.hasPrefix("event:") {
                    pendingEvent = String(line.dropFirst("event:".count)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    pendingData.append(String(line.dropFirst("data:".count)).trimmingCharacters(in: .whitespaces))
                }
                // id:/retry: lines are ignored — the runner never sends
                // them and nothing here has a use for them yet.
            }
        }
        // The runner closes the stream after its final blank-line-terminated
        // frame, so this is normally a no-op — kept as a backstop in case a
        // frame ever arrives without its trailing blank line.
        await flush()
    }
}
