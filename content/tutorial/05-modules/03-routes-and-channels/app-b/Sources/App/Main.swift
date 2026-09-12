import FlightActuator
import FlightCore
import FlightTransport
import FlightWeb
import Foundation
import HTTPTypes

/// A middleware is a value too — an ordinary type conforming to `Middleware`.
/// This one stamps every response it wraps.
struct StampMiddleware: Middleware {
    static let servedBy = HTTPField.Name("X-Served-By")!

    func handle(_ context: RequestContext, next: Next) async throws -> Response {
        let response = try await next(context)
        return response.settingHeader(Self.servedBy, "PingModule")
    }
}

/// A module that contributes to the web layer with *values*, not annotations:
/// a couple of routes and a middleware lane. Nothing here is scanned — the
/// composition root gathers these arrays from every module and folds them in.
struct PingModule: FlightModule {
    static var dependencies: [any FlightModule.Type] { [] }

    let routes: [RouteRegistration]
    let middleware: [MiddlewareRegistration]

    init(configuration: Configuration) {
        let version = configuration.get("app.version", default: "0.0.0")
        self.routes = [
            RouteRegistration(method: .get, path: "/ping") { context in
                try "pong".response(for: context)
            },
            RouteRegistration(method: .get, path: "/ping/version") { context in
                try "PingModule \(version)".response(for: context)
            },
        ]
        // The value form of a pipeline: this module owns the middleware
        // instance, so there is nothing to resolve — the lane is declared with
        // the instance in hand.
        self.middleware = MiddlewareRegistration.lane(.default, [StampMiddleware()])
    }
}

@main
struct Main {
    static func main() async {
        await Flight.run(
            configuration: try Configuration.load(),
            modules: [
                FlightWebModule<FlightTransport>.self,
                PingModule.self,
                ActuatorModule.self,
            ],
            composedBy: flightComposeModules
        )
    }
}
