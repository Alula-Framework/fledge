---
title: Project anatomy
description: What flight new skeleton actually generates, file by file.
order: 3
---

Run `flight new MyService` and you get this:

```
MyService/
  Package.swift
  flight.yaml
  Sources/App/
    Main.swift
    Controllers/
      HealthController.swift
    Entities/      (empty — basics adds to it)
    Repos/         (empty — basics adds to it)
    Services/      (empty)
  Tests/AppTests/
    HealthControllerTests.swift
```

Seven files with anything in them. Every one is worth reading before you
add an eighth.

## `Package.swift` — one dependency, one trait

```swift
let package = Package(
    name: "App",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "App", targets: ["App"])],
    dependencies: [
        .package(url: "https://github.com/Flight-Framework/flight.git", from: "0.18.0", traits: ["Web"])
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "FlightCore", package: "flight"),
                .product(name: "FlightWeb", package: "flight"),
                .product(name: "FlightTransport", package: "flight"),
                .product(name: "FlightActuator", package: "flight"),
            ],
            plugins: [.plugin(name: "FlightRegistrationPlugin", package: "flight")]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["App", /* … */ .product(name: "FlightWebTesting", package: "flight")]
        ),
    ]
)
```

`traits: ["Web"]` is the whole story of what got resolved: HTTP,
WebSockets, Channels, and Presence — no database driver, no security
module, because neither was named. `FlightTransport` is itself a choice,
not a given: it wraps HummingbirdCore, and any type conforming to the same
transport protocol is a peer you could swap in.

The plugin line matters more than it looks: `FlightRegistrationPlugin`
scans this target for `@Component`/`@Controller`/`@Service` at *build*
time and generates the composition root (`flightComposeModules`) that builds
and wires them. There is no runtime route table anywhere in this project for
you to find and mutate.

## `flight.yaml` — layer 3 of configuration

```yaml
app:
  name: App

server:
  host: 127.0.0.1
  port: 8080

actuator:
  format: json
```

"Layer 3" because environment variables (`FLIGHT_*`) layer over this file,
and both are frozen into an immutable `Configuration` once, at bootstrap.
Nothing re-reads this file while the process is running — change a value,
restart the process. That's a deliberate trade: a config value can't drift
mid-request, and every route you write can trust the value it read a
minute ago is still the value it would read now.

## `Sources/App/Main.swift` — the whole boot sequence, in one place

```swift
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
                AppModule.self,
                ActuatorModule.self,
            ],
            composedBy: flightComposeModules
        )
    }
}
```

Read this and you've read the order events happen in, for every Flight
app you'll ever open: configuration loads, the modules are composed in
dependency order — each module's `dependencies` form a DAG that's resolved
once — every `@Controller`, `@Service`, `@Repository`, and `@Component` is
built a single time and wired by type, and *only then* does the server start
accepting requests. Nothing serves traffic against a half-built graph —
there's no window where a request could arrive before your controllers exist.

`Flight.run` rather than `main() async throws` is deliberate: an error
escaping `main` prints a raw runtime backtrace, while `run` prints the reason
(Postgres down, port already bound) and exits 1.

`flightComposeModules` is the composition root the registration plugin
generated. `AppModule` is a *value* — no `configure` method, no registration
call. Adding a controller to this project means writing the controller, not
editing `Main.swift`; the plugin finds the new type at build time and wires it
in.

## `Controllers/HealthController.swift` — the one route worth curling

```swift
@Controller
struct HealthController {
    @ConfigValue("app.name") var appName: String

    @GetRoute("/")
    func index(_ context: RequestContext) -> String {
        "\(appName) is flying"
    }
}
```

Two macros doing real work here. `@Controller` is what the registration
plugin looks for — no separate step registers this route anywhere.
`@ConfigValue("app.name")` reads `flight.yaml`'s `app.name` key, and
because there's no `default:` argument, the *build* — not a runtime
crash — fails if that key doesn't exist. Misspell a config key and you
find out from the compiler, not from a customer.
