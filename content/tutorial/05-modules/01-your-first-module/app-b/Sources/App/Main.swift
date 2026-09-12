import FlightActuator
import FlightCore
import FlightTransport
import FlightWeb
import Foundation

/// A plain value the scan has no way to build — so a module builds it and
/// holds it.
struct Clock: Sendable {
    let now: @Sendable () -> Date
}

struct AppModule: FlightModule {
    static var dependencies: [any FlightModule.Type] { [] }

    /// Provided to any `@Inject var clock: Clock`, matched by type. The
    /// composition root reads the declared type off this stored property to
    /// wire it, which is why the annotation is required, not optional.
    let clock: Clock = Clock(now: { Date() })
}

@main
struct Main {
    static func main() async {
        await Flight.run(
            configuration: try Configuration.load(),
            modules: [
                FlightWebModule<FlightTransport>.self,
                AppModule.self,
                ActuatorModule.self,
            ],
            composedBy: flightComposeModules
        )
    }
}
