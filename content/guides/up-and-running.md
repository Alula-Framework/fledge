---
title: Up and Running
description: From an empty directory to a running Alula app in one page.
order: 0
category: Alula
---

```bash
alula new MyService
cd MyService
swift run
```

`alula new` generates a complete, buildable project from one of three
tiers — `skeleton` (the smallest thing that runs), `basics`, or `demo` —
defaulting to `skeleton`. The alternative most frameworks choose is one
starting template with everything wired in, disabled by config flags.
Alula's tiers are a different bet: what you didn't ask for was never
resolved, so it can never be a build you have to explain. A `skeleton`
project's `Package.swift` has exactly one dependency line naming exactly
one trait — that line is the whole story of what the project depends on.

## What you get

```
MyService/
  Package.swift
  alula.yaml
  Sources/App/
    Main.swift
    Controllers/HealthController.swift
    Entities/      (empty)
    Repos/         (empty)
  Tests/AppTests/HealthControllerTests.swift
```

`Main.swift` is the whole boot sequence, in one place: configuration
loads, the modules compose in dependency order (each module's
`dependencies` forming a DAG resolved once), every component is built
once, and only then does the server start accepting requests. There's no
window where a request could arrive against a half-built graph.

`HealthController` is the one route worth curling once `swift run` is up:

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

```bash
curl http://127.0.0.1:8080/
# App is flying
```

Two macros doing real work: `@Controller` is what the build-time
registration plugin looks for — no separate step registers this route
anywhere. `@ConfigValue("app.name")` reads `alula.yaml`'s `app.name` key,
and because there's no `default:` argument, a misspelled key is a
*build* failure, not a runtime surprise.

## Tests, from the same command

```bash
swift test
```

The generated test drives the same route through `TestClient` — routing,
middleware, and dependency injection all run for real, with no socket and
no port to collide with. It builds the graph and its routes the way the
composition root does, then dispatches against them:

```swift
@Test("the index route answers with the configured application name")
func index() async throws {
    let graph = try AlulaGraph(configuration: Configuration(values: ["app.name": "TestApp"]))
    let client = try TestClient(routes: alulaRoutes(graph))
    let response = await client.get("/")
    #expect(response.bodyText == "TestApp is flying")
}
```

## Where to go next

- [Routing and Controllers](/guides/routing-and-controllers) — the next
  thing worth adding to `HealthController`'s file.
- [Configuration](/guides/configuration) — the three layers `app.name`
  above actually comes from.
- [Testing](/guides/testing) — the direct unit-test tier most of your
  tests should be, and where this end-to-end style fits.

[Part 0 of the tutorial](/tutorial/00-setup) walks through all of this
one exercise at a time, including what each generated file is for.
