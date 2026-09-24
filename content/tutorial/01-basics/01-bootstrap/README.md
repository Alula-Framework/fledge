---
title: Bootstrap, modules, and the composition root
description: What the composition root wires, and in what order.
order: 1
---

Every Alula app boots the same few steps, in the same order, every time.
Once you've seen them once, you've seen every Alula app's startup:

```swift
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
```

1. **`Configuration.load()`** reads `alula.yaml` plus `ALULA_*`
   environment variables into one immutable value.
2. **The modules are composed**, in dependency order — each module's
   `dependencies` form a DAG that's resolved once, not hoped for. `modules:`
   names which subsystems the app includes; `composedBy: alulaComposeModules`
   is how they're built.
3. **Every component is built once, eagerly.** The composition root constructs
   each `@Controller`, `@Service`, `@Repository`, and `@Component` a single
   time and wires them together by type. A missing dependency, or a required
   `@ConfigValue` that isn't there, fails *here* — at startup — not as a
   runtime surprise three requests later.
4. **The server starts accepting connections.** Not before: there is no window
   where a request could arrive against a half-built graph.

`Alula.run` rather than `main() async throws` is deliberate — an error
escaping `main` prints a raw runtime backtrace, while `run` prints the reason
(Postgres down, port already bound) and exits 1.

## Your module

`AppModule` is the one file that says what your app is made of:

```swift
struct AppModule: AlulaModule {
    static var dependencies: [any AlulaModule.Type] { [] }
}
```

That's the whole thing — a *value* declaring which subsystems the app is built
on. There is no `configure` method and no registration call to write.
Everything else — every `@Component`, `@Controller`, `@Service`, and
`@Repository` — is wired by `alulaComposeModules`, the **composition root**
the `AlulaRegistrationPlugin` (named in `Package.swift`'s `plugins:` list)
generates for you.

That plugin scans your target at *build* time for every annotated type and
writes the code that builds and wires all of them, in dependency order. Add a
controller, and it's picked up on the next build — you never edit `AppModule`
to wire in a new route.

## Why a DAG, not a list

`static var dependencies` matters the moment your app has more than one module.
If `AppModule` needs something another module provides, naming that module in
`dependencies` guarantees it's built first — regardless of the order modules
appear in `Main.swift`'s array. You'll see this directly once Part 2 adds a
database module ahead of your own.

**Try it — this is the exercise.** In a project of your own
(`alula new --tier skeleton myapp`, from Part 0), add
`Sources/App/Controllers/StatusController.swift`:

```swift
import AlulaCore
import AlulaWeb

@Controller
struct StatusController {
    @ConfigValue("app.name") var appName: String

    @GetRoute("/status")
    func status(_ context: RequestContext) -> String {
        "\(appName): up"
    }
}
```

`swift run`, then `curl 127.0.0.1:8080/status` — it answers `App: up`, and
nothing in `AppModule` or `Main.swift` changed to make that happen. That's the
composition root doing its job: the plugin found the new type at build time and
wired it in.

`@ConfigValue("app.name")` is a preview of the configuration exercise, but it's
worth noticing now for a different reason: it has no `default:`, so the build
plugin checks that `app.name` actually exists in `alula.yaml`. Misspell it and
the build fails naming the key — a wrong config key is a compile error here,
not a 3am page.
