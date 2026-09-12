import FlightActuator
import FlightCore
import FlightTransport
import FlightWeb
import GreetKit

struct AppModule: FlightModule {
    static var dependencies: [any FlightModule.Type] { [] }
}

@main
struct Main {
    static func main() async {
        await Flight.run(
            configuration: try Configuration.load(),
            modules: [
                FlightWebModule<FlightTransport>.self,
                // The installed module, listed by name. The composition root
                // finds it in the GreetKit package, builds it, and folds in
                // the routes it brings.
                GreetingModule.self,
                AppModule.self,
                ActuatorModule.self,
            ],
            composedBy: flightComposeModules
        )
    }
}
