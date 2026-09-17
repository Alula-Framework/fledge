---
title: Packaging a module for reuse
description: Shipping a module in its own package, the way FlightSecurityModule and friends do.
order: 5
---

Everything you've built so far has lived in the application. But a module is
just a value with a small public surface, and nothing ties it to the app it
started in. Move it into its own package and it becomes installable — the
exact shape `FlightWebModule`, `FlightSecurityModule`, and every other
framework module already ship in. There is no separate "library module"
concept; the framework's modules and yours are the same kind of thing, resolved
the same way.

## The library package

A reusable module is an ordinary Swift library that depends on `flight`:

```swift
// GreetKit/Package.swift
let package = Package(
    name: "GreetKit",
    platforms: [.macOS(.v15)],
    products: [.library(name: "GreetKit", targets: ["GreetKit"])],
    dependencies: [
        .package(url: "https://github.com/Flight-Framework/flight.git",
                 from: "0.18.0", traits: ["Web"])
    ],
    targets: [
        .target(name: "GreetKit", dependencies: [
            .product(name: "FlightCore", package: "flight"),
            .product(name: "FlightWeb", package: "flight"),
        ])
    ]
)
```

Two things are notably *absent*, and both follow from one fact — a library
starts nothing:

- **No `FlightRegistrationPlugin`.** The plugin generates a composition root
  from a bootstrap list, and a library has none. The *application* that
  installs GreetKit runs the plugin, and its scan reaches across into GreetKit's
  source to find your module. A library that ran the plugin would just generate
  an empty root.
- **No transport, no `@main`.** Those belong to the application. The library
  ships the module and whatever it provides, nothing more.

The module itself is what you already know how to write — with one addition:
everything the composition root touches must be `public`.

```swift
// GreetKit/Sources/GreetKit/GreetingModule.swift
public struct GreetingModule: FlightModule {
    public static var dependencies: [any FlightModule.Type] { [] }

    public let routes: [RouteRegistration]

    public init(configuration: Configuration) {
        let name = configuration.get("app.name", default: "Flight")
        self.routes = [
            RouteRegistration(method: .get, path: "/greeting") { context in
                try "Hello from \(name)".response(for: context)
            }
        ]
    }
}
```

The `public` matters: the struct, `dependencies`, the provided `routes`, and
the `init` all have to cross the package boundary for the consuming app's
generator to see and build the module. A non-public member is invisible to it —
the same way any other type hidden behind a package boundary would be.

This module brings its own route, so it's *fully self-contained*: installing it
is the whole integration. That's the strongest form a reusable module takes,
but it's not required — a packaged module can just as well provide a value for
the app's own controllers to inject, exactly as the earlier exercises did.

## Installing it

An application adds the package and names the module. Nothing else:

```swift
// the app's Package.swift
dependencies: [
    .package(url: "https://github.com/Flight-Framework/flight.git", from: "0.18.0", traits: ["Web"]),
    .package(url: "https://github.com/you/GreetKit.git", from: "1.0.0"),
],
// ...and on the App target:
.product(name: "GreetKit", package: "GreetKit"),
```

```swift
// the app's Main.swift
import GreetKit

modules: [
    FlightWebModule<FlightTransport>.self,
    GreetingModule.self,   // the installed module, listed by name
    AppModule.self,
    ActuatorModule.self,
]
```

Add the dependency, list the module, and the composition root does the rest —
builds `GreetingModule`, sees it needs `configuration`, supplies it, and folds
the routes it brings into the web layer. If the module had declared
`dependencies`, those would come along too, exactly as in the earlier
exercises. From the outside, your module is indistinguishable from a framework
one: `FlightSecurityModule` is a `public struct FlightModule` in a package,
providing `public let middleware`, installed by listing it. You've been using
modules packaged this way since Part 1 — now you can ship your own.

**Try it.** The solution ships GreetKit as a sibling directory and depends on
it by path (`.package(path: "GreetKit")`) so the two travel together; a real
module would live in its own repository and be depended on by URL. Build the
app and `curl 127.0.0.1:8080/greeting` — the route came entirely from the
installed package, and the application's own code never mentions a path or a
handler for it.
