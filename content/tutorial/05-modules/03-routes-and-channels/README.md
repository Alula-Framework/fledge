---
title: Contributing routes, channels, and middleware
description: A module offers [RouteRegistration] / [ChannelRegistration] / [MiddlewareRegistration] as values; the root aggregates them.
order: 3
---

So far a module has provided *values* that controllers inject. But a module can
also contribute to the web layer directly — add routes, install middleware,
declare channels — without a single annotation. It does this the same way it
provides anything: by holding the right value as a stored property. The
difference is that these are *arrays*, and the composition root gathers them
from **every** module and concatenates them.

## Routes as values

A `@GetRoute` is the ergonomic way to declare a route, but underneath, a route
is just a `RouteRegistration` — a method, a path, and a handler. A module can
build them directly, which is what you reach for when the routes are computed
(mounting the same handler under several prefixes) or come from a library
rather than from your own annotated controllers:

```swift
struct PingModule: AlulaModule {
    static var dependencies: [any AlulaModule.Type] { [] }

    let routes: [RouteRegistration]

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
    }
}
```

A handler here is a plain `@Sendable (RequestContext) async throws -> Response`.
There's no macro to turn a returned `String` into a `Response`, so you call
`.response(for: context)` yourself — the exact conversion `@GetRoute` generates
for you when you return a `String` from an annotated method.

## Middleware as values

Middleware works identically. A `Middleware` is an ordinary value — a type with
one `handle(_:next:)` method — and a module installs middleware by holding a
`[MiddlewareRegistration]`, built with `MiddlewareRegistration.lane`:

```swift
struct StampMiddleware: Middleware {
    static let servedBy = HTTPField.Name("X-Served-By")!

    func handle(_ context: RequestContext, next: Next) async throws -> Response {
        let response = try await next(context)
        return response.settingHeader(Self.servedBy, "PingModule")
    }
}

// inside the module:
let middleware: [MiddlewareRegistration]
// inside init:
self.middleware = MiddlewareRegistration.lane(.default, [StampMiddleware()])
```

`.lane(_:_:)` names a pipeline lane and the middleware in it, in order,
outermost first. `.default` is the lane every route runs through unless it
names others; `.authenticated`, `.authentication`, and `.public` are the other
built-in lanes, and you can declare your own just by naming it. Because the
module owns the *instance* (`StampMiddleware()`), there's nothing to look up —
the value form of what a runtime container's `pipeline { }` block used to do.

## How the root folds them together

Read the generated composition root and the aggregation is right there:

```swift
let pingModule = PingModule(configuration: configuration)
let alulaWebModule = try AlulaWebModule<AlulaTransport>(
    configuration: configuration,
    routes: alulaRoutes(alulaGraph) + pingModule.routes + actuatorModule.routes,
    middleware: pingModule.middleware)
```

The root finds every module that exposes a `[RouteRegistration]`, a
`[MiddlewareRegistration]`, or a `[ChannelRegistration]`, and concatenates each
kind — matched by the array's *element* type, the same by-type rule that wires
single values. Two details worth seeing:

- **Your application's own routes come first.** `alulaRoutes(alulaGraph)` —
  the routes generated from your `@Controller`s — precede the modules'
  contributions in the table, so an app route and a module route at the same
  path resolve the way you'd expect.
- **Empty is fine.** A module that contributes no routes simply doesn't have a
  `routes` property; nothing forces the array to exist.

## Channels are the same shape

You've already met `[ChannelRegistration]` in Part 4 — a channels module holds

```swift
let channels: [ChannelRegistration]
```

and the root gathers those from every module exactly as it gathers routes and
middleware, handing the combined list to `AlulaChannelsModule`. Realtime
topics, HTTP routes, and middleware lanes are not three different extension
mechanisms; they are one — a stored array the composition root aggregates by
element type. That uniformity is the whole reason "add a subsystem" is the same
motion whether the subsystem is yours or the framework's.

**Try it.** Add `PingModule` to a `skeleton` project (the skeleton keeps its
own `HealthController` at `/`). Then `curl -i 127.0.0.1:8080/ping` — you get
`pong`, and every response, including the skeleton's `/`, carries the
`X-Served-By: PingModule` header, because the middleware lane wraps the whole
default pipeline, not just this module's routes.
