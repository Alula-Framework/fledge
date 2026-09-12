import FlightActuator
import FlightCore
import FlightTransport
import FlightWeb
import Foundation
import Logging
import ServiceLifecycle

/// A long-running component: it starts when the app starts, runs until the app
/// shuts down, and is cancelled cleanly when it does. Conforms to
/// ServiceLifecycle's `Service` — one `run()` method.
struct HeartbeatService: Service {
    let interval: Duration
    let logger: Logger

    func run() async throws {
        // `cancelWhenGracefulShutdown` turns the group's shutdown signal into
        // ordinary task cancellation, so the loop exits by *returning* rather
        // than by throwing — a clean stop, not a failure.
        await cancelWhenGracefulShutdown {
            while !Task.isCancelled {
                guard (try? await Task.sleep(for: interval)) != nil else { return }
                logger.info("heartbeat")
            }
        }
    }
}

/// A module that *owns* a service. `service` is the one place a module hands a
/// long-running component to the app-wide lifecycle. Everything else about the
/// module is unchanged — it is still a value built by the composition root.
struct HeartbeatModule: FlightModule {
    static var dependencies: [any FlightModule.Type] { [] }

    let heartbeat: HeartbeatService

    init(configuration: Configuration) {
        let seconds = configuration.get("heartbeat.intervalSeconds", default: 5)
        self.heartbeat = HeartbeatService(
            interval: .seconds(seconds),
            logger: Logger(label: "app.heartbeat"))
    }

    /// Handed to the ServiceGroup at bootstrap. `serviceShutdownPhase` (default
    /// `.standard`) decides when it stops relative to the transport and the
    /// infrastructure; a heartbeat is an ordinary service, so the default fits.
    var service: (any Service)? { heartbeat }
}

@main
struct Main {
    static func main() async {
        await Flight.run(
            configuration: try Configuration.load(),
            modules: [
                FlightWebModule<FlightTransport>.self,
                HeartbeatModule.self,
                ActuatorModule.self,
            ],
            composedBy: flightComposeModules
        )
    }
}
