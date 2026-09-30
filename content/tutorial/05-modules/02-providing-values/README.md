---
title: Modules that depend on modules
description: Pull in a stack with dependencies, and receive configuration and another module's value through your init.
order: 2
---

The `Clock` from the last exercise was easy to provide because it was a
literal — `Clock(now: { Date() })` needs nothing to build. Most values a
module owns aren't like that. A database client needs a connection string. A
mailer needs an API key. A thing that greets people needs to know the app's
name and what time it is. These can only be *constructed* once their inputs
exist — so the module builds them in its initializer, and the composition root
supplies what the initializer asks for.

## An initializer the root can satisfy

Here is a module whose value is derived rather than literal:

```swift
struct Greeter: Sendable {
    let clock: Clock
    let name: String

    func greeting() -> String {
        let hour = Calendar.current.component(.hour, from: clock.now())
        let partOfDay = hour < 12 ? "morning" : hour < 18 ? "afternoon" : "evening"
        return "Good \(partOfDay) from \(name)"
    }
}

struct GreetingModule: AlulaModule {
    static var dependencies: [any AlulaModule.Type] { [ClockModule.self] }

    let greeter: Greeter

    init(configuration: Configuration, clock: Clock) {
        let name = configuration.get("app.name", default: "Alula")
        self.greeter = Greeter(clock: clock, name: name)
    }
}
```

The composition root builds `GreetingModule` by looking at that initializer and
satisfying each parameter *by type* — the same matching rule that connected an
`@Inject var clock: Clock` to a provided `Clock` in the last exercise, now
applied to a module's own construction. Two kinds of thing can satisfy a
parameter:

- **`configuration: Configuration`** — the loaded `Configuration`, which the
  root always has. Any module can ask for it. (The root supplies a few more
  values itself: the component graph, `AlulaGraph`, which exercise 4 comes
  back to; the shared `ModuleHealthRegistry` Actuator reports from; and the
  `OpenAPIDocument` the build derives from your routes.)
- **`clock: Clock`** — a value *another module provides*. Here that's
  `ClockModule.clock`. The root finds the one module offering a `Clock` and
  passes it.

You can read the result straight out of the generated composition root:

```swift
let clockModule = ClockModule()
let greetingModule = GreetingModule(configuration: configuration, clock: clockModule.clock)
```

`clockModule` is built first — not because it appears earlier in a list, but
because `greetingModule` can't be constructed until its `clock` argument
exists. Construction order is *derived from the values*, which is why the last
exercise insisted `dependencies` is not an ordering knob: it only breaks ties
the values leave open.

## `dependencies` is what pulls ClockModule in

Look at the bootstrap list — `ClockModule` isn't in it:

```swift
modules: [
    AlulaWebModule<AlulaTransport>.self,
    GreetingModule.self,
    ActuatorModule.self,
]
```

It doesn't need to be. `GreetingModule` names `ClockModule` in its
`dependencies`, and that's an *inclusion* edge: including a module includes
everything it depends on, recursively. So the bootstrap list names the modules
you're deliberately choosing, and their prerequisites arrive on their own —
the same reason your `AppModule` never had to list `AlulaWebModule`'s internals.

This is the seam that makes a module *reusable*: a module you install names
what it needs, and installing it is enough. The next exercises build on it —
`AlulaGraph`, and framework modules like the database and channels layers, all
reach a consuming module through exactly this init-parameter matching.

## When two modules provide the same type

Matching by type has one failure mode worth knowing before you hit it: if *two*
modules both provide a `Clock`, nothing in `GreetingModule`'s `clock:` parameter
says which one it meant, so the root refuses to guess — the build fails with
`ALU-DI-1002`, "2 modules provide `Clock`, and it is asked for by type", with a
note at each provider.

Two providers of one type is a shape worth having, though — a system clock and
a fixed one you pin in tests — so the answer isn't to rename the type until the
collision goes away. You nominate a default instead:

```swift
struct GreetingModule: AlulaModule {
    static var dependencies: [any AlulaModule.Type] { [ClockModule.self] }
    // Which provider an unqualified match resolves to, for types that have more
    // than one. Only ambiguous types consult it.
    static var defaultProviders: [any AlulaModule.Type] { [ClockModule.self] }
    ...
}
```

The nomination is read from every module in the graph, so it can live on any of
them; putting it on the module that pulls both in is the convention, because
that's where a reader goes looking. Now every unqualified match — the `clock:`
parameter above included — resolves to `ClockModule.clock`.

Where a *component* wants the other one, it says so at its injection site:

```swift
@Service
struct AuditTrail {
    @Inject(from: FixedClockModule.self) var clock: Clock
}
```

One asymmetry to know before you rely on it: `@Inject(from:)` is a property
annotation, so components can name a provider and a module's initializer
parameters cannot. A module init always receives the default. If a module needs
specifically the *other* provider, make that one the default and annotate the
components that want the first.

Either way the ambiguity is a build-time error, never a runtime coin-flip — and
the error text spells out both lines above with your own names already
substituted into them, so you don't have to remember this page.

**Try it.** In a `skeleton` project, add both modules and the
`GreetingController`, then `curl 127.0.0.1:8080/greeting` — the reply changes
with the time of day and carries whatever `app.name` your `alula.yaml` sets.
Then try removing `ClockModule` from `GreetingModule.dependencies` while still
listing neither in `modules:`: the build fails. With no module providing a
`Clock`, nothing can fill that initializer parameter, and the generator says
so at the module, parameter by parameter:

```
Sources/MyService/Main.swift:32:8: error: [ALU-LIFE-8002] no initializer of `GreetingModule` can be satisfied by this application
    init(configuration:clock:) needs:
      clock: Clock — nothing provides it
    A module's parameters must be values another module provides, `Configuration`, or the component graph.
    help: add the modules that provide those values, give the parameters defaults, or add an initializer this application can satisfy.
    docs: https://github.com/Alula-Framework/alula/blob/main/Diagnostics/ALU-LIFE-8002.md
```

`configuration` isn't listed — the root always has one — so what's left is
exactly the parameter nobody provides. The unsatisfiable dependency is a build
error, before anything runs.
