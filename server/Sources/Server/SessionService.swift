import AlulaChannels
import Foundation

/// The execution module (PLAN §4): bridges HTTP session/run requests to the
/// leased runner and fans build/run output out to `session:<id>` channel
/// subscribers. No HTTP response ever blocks on a full run finishing —
/// `run(sessionID:)` dispatches the runner call and returns immediately,
/// because the actual output arrives over the channel the browser is
/// expected to have already joined, not the HTTP response body.
struct SessionService: Sendable {
    let broker: SessionBroker
    let client: RunnerClient
    let broadcaster: ChannelBroadcaster
    let postgres: PostgresAdmin

    static func topic(for sessionID: String) -> String { "session:\(sessionID)" }

    /// Reuses `existingSessionID` if it's still live; otherwise claims a
    /// runner from the pool, provisions this session's own database
    /// (PLAN §3's `db` tier — every session gets one, see
    /// `PostgresAdmin`'s doc comment for why that's simpler than deciding
    /// per exercise), leases the runner over HTTP with that database's
    /// connection string, and mints a fresh session id. The session id
    /// itself is the only credential a joining socket presents (see
    /// SessionChannel) — consistent with v1 having no accounts at all
    /// (PLAN §1): knowing the id is exactly as much proof of ownership as
    /// the `HttpOnly` cookie it travels in.
    func getOrCreateSession(existingSessionID: String?) async throws -> String {
        if let id = existingSessionID, await broker.touch(sessionID: id) != nil {
            return id
        }
        guard let runnerBaseURL = await broker.claimRunner() else {
            throw SessionBroker.BrokerError.poolExhausted
        }
        let sessionID = UUID().uuidString
        do {
            let databaseURL = try await postgres.createSessionDatabase(sessionID: sessionID)
            do {
                let leaseID = try await client.lease(baseURL: runnerBaseURL, databaseURL: databaseURL)
                await broker.attach(sessionID: sessionID, lease: .init(runnerBaseURL: runnerBaseURL, leaseID: leaseID))
                return sessionID
            } catch {
                // The database exists but the runner never accepted it —
                // drop it rather than leaking a database with nothing
                // that will ever reap it (the broker never learned this
                // session id, so SessionReaperService can't find it either).
                try? await postgres.dropSessionDatabase(sessionID: sessionID)
                throw error
            }
        } catch {
            await broker.unclaim(runnerBaseURL)
            throw error
        }
    }

    func write(sessionID: String, content: String) async throws {
        guard let lease = await broker.touch(sessionID: sessionID) else {
            throw SessionBroker.BrokerError.unknownSession
        }
        try await client.write(baseURL: lease.runnerBaseURL, leaseID: lease.leaseID, content: content)
    }

    func reset(sessionID: String) async throws {
        guard let lease = await broker.touch(sessionID: sessionID) else {
            throw SessionBroker.BrokerError.unknownSession
        }
        try await client.reset(baseURL: lease.runnerBaseURL, leaseID: lease.leaseID)
    }

    /// Kicks the run off in a detached task and returns as soon as the
    /// session's lease is confirmed live — see the type doc. A failure
    /// calling the runner itself (not a build/run failure — those arrive
    /// as ordinary `build_output`/`exited` events) surfaces as a
    /// `run_error` event on the same topic rather than a channel-protocol
    /// `alula:error`, which is reserved for join/handle failures, not
    /// side-channel work triggered outside the channel entirely.
    func run(sessionID: String) async throws {
        guard let lease = await broker.touch(sessionID: sessionID) else {
            throw SessionBroker.BrokerError.unknownSession
        }
        let topic = Self.topic(for: sessionID)
        let broadcaster = broadcaster
        let client = client
        Task {
            do {
                try await client.run(baseURL: lease.runnerBaseURL, leaseID: lease.leaseID) { event, data in
                    await broadcaster.broadcast(topic: topic, event: event, payload: .object(["data": .string(data)]))
                }
            } catch {
                await broadcaster.broadcast(
                    topic: topic, event: "run_error",
                    payload: .object(["message": .string(String(describing: error))]))
            }
        }
    }

    /// An explicit end to a session (as opposed to idle-timeout reaping,
    /// which `SessionReaperService` drives) — releases the runner back to
    /// the pool right away instead of waiting out the idle timeout.
    func endSession(sessionID: String) async {
        guard let lease = await broker.detach(sessionID: sessionID) else { return }
        try? await client.release(baseURL: lease.runnerBaseURL, leaseID: lease.leaseID)
        try? await postgres.dropSessionDatabase(sessionID: sessionID)
    }
}
