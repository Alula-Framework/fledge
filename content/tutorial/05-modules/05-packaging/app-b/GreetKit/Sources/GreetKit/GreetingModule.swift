import AlulaCore
import AlulaWeb

/// A self-contained module: it brings its own route. An application installs
/// it by adding the package and naming `GreetingModule` in its `modules:`
/// list — nothing else. Everything the module needs it constructs itself, so
/// there is no wiring for the consumer to get wrong.
///
/// The type and every member the composition root touches are `public`: the
/// struct, `dependencies`, the provided `routes`, and `init`. A module the
/// composer can't see across the package boundary can't be built.
public struct GreetingModule: AlulaModule {
    public static var dependencies: [any AlulaModule.Type] { [] }

    public let routes: [RouteRegistration]

    public init(configuration: Configuration) {
        let name = configuration.get("app.name", default: "Alula")
        self.routes = [
            RouteRegistration(method: .get, path: "/greeting") { context in
                try "Hello from \(name)".response(for: context)
            }
        ]
    }
}
