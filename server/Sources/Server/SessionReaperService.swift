import FlightChannels
import FlightCore
import Logging
import ServiceLifecycle

/// The periodic half of the sessions module (PLAN §4: "idle TTL reaper").
/// Every `reapIntervalSeconds`, sweeps sessions past the idle timeout or hard
/// cap, tells each one's runner to release the lease (scrubbing its workspace
/// back to pristine), drops its session database, and pushes a
/// `session_expired` event so a still-connected browser learns its session is
/// gone rather than silently getting 404s on its next request.
///
/// Built by `AppModule` from the values the composition root wired into it —
/// no stashed `Container`, no `resolve` at `run()`.
struct SessionReaperService: Service, Sendable {
    let broker: SessionBroker
    let client: RunnerClient
    let broadcaster: ChannelBroadcaster
    let postgres: PostgresAdmin
    let configuration: Configuration
    let logger: Logger

    init(
        broker: SessionBroker,
        client: RunnerClient,
        broadcaster: ChannelBroadcaster,
        postgres: PostgresAdmin,
        configuration: Configuration,
        logger: Logger = Logger(label: "flight-school.server.reaper")
    ) {
        self.broker = broker
        self.client = client
        self.broadcaster = broadcaster
        self.postgres = postgres
        self.configuration = configuration
        self.logger = logger
    }

    func run() async throws {
        let interval = try configuration.getIfPresent("session.reapIntervalSeconds", as: Int.self) ?? 30

        await cancelWhenGracefulShutdown {
            while !Task.isCancelled {
                guard (try? await Task.sleep(for: .seconds(interval))) != nil else { return }
                let expired = await broker.reapExpired()
                guard !expired.isEmpty else { continue }
                logger.info("reaped \(expired.count) idle session(s)")
                for (sessionID, lease) in expired {
                    do {
                        try await client.release(baseURL: lease.runnerBaseURL, leaseID: lease.leaseID)
                    } catch {
                        logger.error("failed to release runner \(lease.runnerBaseURL) for reaped session \(sessionID): \(error)")
                    }
                    do {
                        try await postgres.dropSessionDatabase(sessionID: sessionID)
                    } catch {
                        logger.error("failed to drop database for reaped session \(sessionID): \(error)")
                    }
                    await broadcaster.broadcast(
                        topic: SessionService.topic(for: sessionID), event: "session_expired")
                }
            }
        }
    }
}
