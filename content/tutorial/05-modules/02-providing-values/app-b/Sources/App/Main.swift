import FlightActuator
import FlightCore
import FlightTransport
import FlightWeb
import Foundation

// A module you already know how to write: it provides one value, a Clock.
struct Clock: Sendable {
    let now: @Sendable () -> Date
}

struct ClockModule: FlightModule {
    static var dependencies: [any FlightModule.Type] { [] }
    let clock: Clock = Clock(now: { Date() })
}

/// The value this exercise's second module provides. It is *built from* other
/// things — a `Clock` and a configured name — rather than being a literal, and
/// that is the whole point: some values can only be constructed once their
/// inputs exist.
struct Greeter: Sendable {
    let clock: Clock
    let name: String

    func greeting() -> String {
        let hour = Calendar.current.component(.hour, from: clock.now())
        let partOfDay = hour < 12 ? "morning" : hour < 18 ? "afternoon" : "evening"
        return "Good \(partOfDay) from \(name)"
    }
}

struct GreetingModule: FlightModule {
    // Naming ClockModule here pulls it into the application whether or not the
    // bootstrap list mentions it — depending on a module includes its stack.
    static var dependencies: [any FlightModule.Type] { [ClockModule.self] }

    let greeter: Greeter

    // The composition root builds this module by matching each initializer
    // parameter to something it can supply, by type: `configuration` is the
    // loaded Configuration, and `clock` is the value ClockModule provides.
    init(configuration: Configuration, clock: Clock) {
        let name = configuration.get("app.name", default: "Flight")
        self.greeter = Greeter(clock: clock, name: name)
    }
}

@main
struct Main {
    static func main() async {
        await Flight.run(
            configuration: try Configuration.load(),
            // ClockModule is absent here on purpose: GreetingModule depends on
            // it, so it comes along.
            modules: [
                FlightWebModule<FlightTransport>.self,
                GreetingModule.self,
                ActuatorModule.self,
            ],
            composedBy: flightComposeModules
        )
    }
}
