---
title: Your first module
description: A FlightModule is a value — what it declares, and how the composition root wires it.
order: 1
---

You've written controllers, services, and repositories — the `@Controller`,
`@Service`, and `@Repository` types the build plugin scans and the composition
root builds for you. A **module** is the other half of that picture: a value
that says what your application is made of, declares what it depends on, and
provides the things a scan *can't* build.

You've already used one. The `AppModule` from Part 1 is a `FlightModule`:

```swift
struct AppModule: FlightModule {
    static var dependencies: [any FlightModule.Type] { [] }
}
```

That's a complete module — a value with an empty dependency list. It provides
nothing because, so far, everything your app needs is a scanned component the
composition root already builds. A real module does more.

## Providing a value

Not everything is a scanned component. A wrapper around the system clock, a
third-party API client, a value derived from configuration — these are plain
types the scan has no way to construct. A module builds one and holds it:

```swift
struct Clock: Sendable {
    let now: @Sendable () -> Date
}

struct AppModule: FlightModule {
    static var dependencies: [any FlightModule.Type] { [] }

    /// Provided to any `@Inject var clock: Clock`, matched by type. The
    /// composition root reads the declared type off this stored property to
    /// wire it — which is why the annotation is required, not optional.
    let clock: Clock = Clock(now: { Date() })
}
```

Anything that injects a `Clock` now gets this one:

```swift
@Controller
struct TimeController {
    // flight:hand-registered — Clock is provided by AppModule, not scanned
    // from an annotation, so the marker tells the build not to warn.
    @Inject var clock: Clock

    @GetRoute("/time")
    func time(_ context: RequestContext) -> String {
        ISO8601DateFormatter().string(from: clock.now())
    }
}
```

The composition root did two things here, both keyed on *type*: it built
`AppModule` (a value with a `clock`), and when it built `TimeController` it
matched that controller's `@Inject var clock: Clock` against `AppModule.clock`.
No name connected them — only the type `Clock` did. That is the whole wiring
model: a module provides values by type, and consumers ask for them by type.

Two details are load-bearing, and both come straight from how the build works —
it reads your *source*, at build time, before anything runs:

- **The annotation is required.** `let clock: Clock = …` works; `let clock =
  Clock(...)` does not. The scanner reads the declared type to know what the
  module offers; with only an inferred type it sees nothing to provide, and the
  build fails naming the gap — *"A route terminal needs Clock, and no module in
  this application provides it. A module that owns it should expose it as a
  stored property."*
- **The `// flight:hand-registered` marker** acknowledges that `Clock` is
  provided this way rather than scanned as a `@Component`. Without it the build
  warns — an unmarked `@Inject` of a type the scanner never found is usually a
  missing dependency, so the marker is you saying "no, this one is on purpose."

## Why a module, and not just a global

A module is a *value*, built once when the app is composed. `static var
dependencies` says which *other* modules come along when this one is included —
naming one module names its whole stack, so an app that lists `AppModule` and
depends on, say, the database module doesn't also have to list the database
module by hand. It is an inclusion list, not an ordering knob: construction
order isn't read off it. The generator works out the order from the *values* —
if your module's initializer needs a `Clock`, whatever module provides a
`Clock` is built first, because it has to be. The next exercises lean on
exactly that: a module names another in `dependencies` to pull it in, declares
an `init` that takes the value that module provides, and is handed it —
matched by type, the same way `clock` reached the controller.

**Try it.** In a `skeleton` project, add the `Clock` type and the `clock`
property to `AppModule`, add `TimeController`, and `curl 127.0.0.1:8080/time`.
Then delete the `// flight:hand-registered` comment and rebuild — the build
warns about an `@Inject` it can't account for, which is the check earning its
keep — the build still succeeds. Then drop the `: Clock` annotation and rebuild:
this time the build *fails*, because a route needs a `Clock` that now no module
provides. Both mistakes are caught before the app ever runs; the difference is
severity — an unmarked-but-provided injection is a warning, a genuinely
unprovided dependency is a hard error.
