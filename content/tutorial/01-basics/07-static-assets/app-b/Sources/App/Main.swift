import FlightActuator
import FlightCore
import FlightTransport
import FlightWeb

/// Your application's module: one place that says what this app is made of.
///
/// Everything the registration plugin scans — every `@Controller`, `@Service`,
/// `@Repository`, and `@Component` — is wired by the generated composition
/// root, so adding a controller does not mean editing this file.
struct AppModule: FlightModule {
    /// Modules that must be built before this one. The list is a DAG resolved
    /// once at bootstrap, so ordering is checked rather than hoped for.
    static var dependencies: [any FlightModule.Type] { [] }

    /// The empty `"assets"` lane, as a value. Declaring a lane with nothing in
    /// it is the point, not a placeholder: it is how the asset traffic opts out
    /// of everything the default lane carries. `.lane(_:_:)` emits a marker
    /// even for an empty list, so the lane still *exists* to be named — a mount
    /// naming a lane nobody declared fails at startup.
    let middleware: [MiddlewareRegistration] = MiddlewareRegistration.lane("assets", [])

    /// A built frontend, mounted as a routing fallback rather than a route: it
    /// only answers a `GET`/`HEAD` the router did not match. The value form of
    /// the old `container.assets(at:root:pipelines:)`; the composer hands these
    /// to `FlightWebModule` the same way it hands over routes.
    let assets: [AssetMountRegistration] = [
        .mount(at: "/", root: "web/build", pipelines: ["assets"]) { options in
            options.spaFallback = "index.html"
            options.exclude = ["/api"]
            options.cache("no-cache", matching: "index.html")
            options.cache("public, max-age=31536000, immutable", matching: "_app/immutable/**")
        }
    ]
}

@main
struct Main {
    static func main() async {
        // Configuration loads first, then the modules are composed in
        // dependency order, every component is built once, and only then does
        // the server start accepting requests. Nothing serves traffic against
        // a half-built graph.
        //
        // `Flight.run` rather than `main() async throws`: an error escaping
        // `main` is reported by the Swift runtime as "Fatal error: Error
        // raised at top level" followed by a register dump and a backtrace —
        // which is what a new project sees when Postgres is not running or the
        // port is already bound. `run` prints the reason and exits 1.
        await Flight.run(
            configuration: try Configuration.load(),
            modules: [
                FlightWebModule<FlightTransport>.self,
                AppModule.self,
                ActuatorModule.self,
            ],
            // Built by the plugin, in dependency order, from the list above:
            // `modules:` says which subsystems this application includes, and
            // this is how they are constructed.
            composedBy: flightComposeModules
        )
    }
}
