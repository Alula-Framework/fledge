import AlulaActuator
import AlulaCore
import AlulaTransport
import AlulaWeb
import Foundation

/// A plain value the scan has no way to build — so a module builds it and
/// holds it.
struct Clock: Sendable {
    let now: @Sendable () -> Date
}

struct AppModule: AlulaModule {
    static var dependencies: [any AlulaModule.Type] { [] }

    /// Provided to any `@Inject var clock: Clock`, matched by type. The
    /// composition root reads the declared type off this stored property to
    /// wire it, which is why the annotation is required, not optional.
    let clock: Clock = Clock(now: { Date() })
}

@main
struct Main {
    static func main() async {
        await Alula.run(
            configuration: try Configuration.load(),
            modules: [
                AlulaWebModule<AlulaTransport>.self,
                AppModule.self,
                ActuatorModule.self,
            ],
            composedBy: alulaComposeModules
        )
    }
}
