---
title: Configuration
description: alula.yaml, environment variables, and @Settings.
order: 9
---

Bootstrap's first step (§1) was `Configuration.load()`, resolving three
layers into one immutable value — frozen before the container is even
built, so nothing downstream can read a config value that changes mid-run:

1. **`alula.yaml`** — defaults shared by every environment.
2. **`alula-{env}.yaml`** — an overlay for one environment, selected by
   `ALULA_ENV` (`dev` if unset; `test`, `staging`, and `prod` are built in,
   and an app can define more). `ALULA_ENV=staging` loads
   `alula-staging.yaml` on top of the base file.
3. **`ALULA_*` environment variables** — always win over both files.

## One value: `@ConfigValue`

The anatomy exercise (§3) used the required form —
`@ConfigValue("app.name")`, a build error if `app.name` is missing from
`alula.yaml`. A key that's genuinely optional gets a default instead:

```swift
@ConfigValue("app.maintenanceMode", default: false) var maintenanceMode: Bool
```

— which is exactly the property the middleware exercise's `MaintenanceGate`
declared, without naming it yet. Absent from every layer, it's `false`;
present but the wrong shape (a string where a `Bool` was expected) still
fails at bootstrap rather than silently keeping the default.

**Try both forms together** in your own project, with a new controller:

```swift
@Controller
struct ConfigController {
    @ConfigValue("app.name") var appName: String
    @ConfigValue("app.maintenanceMode", default: false) var maintenanceMode: Bool
    @ConfigValue("app.greeting", default: "hello") var greeting: String

    @GetRoute("/config")
    func show(_ context: RequestContext) -> String {
        "name=\(appName) maintenance=\(maintenanceMode) greeting=\(greeting)"
    }
}
```

```
name=App maintenance=false greeting=hello
```

`app.name` came from `alula.yaml`. The other two aren't in any layer at
all — they're their defaults, and the app started anyway, which is the
entire difference between the two forms.

Now break it on purpose: change `"app.name"` to `"app.nam"` and rebuild.
It doesn't start and then fail; it doesn't build at all:

```
Sources/App/Controllers/ConfigController.swift:6:1: error: [ALU-CONFIG-5004] configuration key 'app.nam' is not in alula.yaml, and ConfigController has no default for it
    Without the key or a default, the application would fail at startup.
    help: add 'app.nam' to alula.yaml — a ${VAR} placeholder is fine for a value the environment supplies —
          or give the @ConfigValue a `default:`.
    docs: https://github.com/Alula-Framework/alula/blob/main/Diagnostics/ALU-CONFIG-5004.md
```

That's the build plugin, not the runtime — a misspelled config key is a
compile error that names the key and both ways to fix it. The code in
brackets is stable: `alula explain ALU-CONFIG-5004` prints its page, and
[When the Build Says No](/guides/diagnostics) explains how to read these.

## A related group: `@Settings`

Several keys that belong together bind once as a typed struct instead of
one `@ConfigValue` per field:

```swift
@Settings("issues")
struct IssuesSettings {
    var pageSize: Int = 25
    var maxPageSize: Int = 100
}
```

```yaml
issues:
  page-size: 25
  max-page-size: 100
```

`pageSize` binds `issues.page-size` — every property name is transformed
`camelCase` → `kebab-case` to build its key, matching `alula.yaml`'s own
convention. Resolve it exactly like any other component:

```swift
@Controller
struct IssueController {
    @Inject var settings: IssuesSettings

    @GetRoute("/issues")
    func index(_ context: RequestContext) -> String {
        "page size: \(settings.pageSize)"
    }
}
```

This half is prose rather than something to run here: `@Settings` needs
its keys in `alula.yaml`, and that file is deliberately not editable in
these exercises — it carries the host and port the preview pane depends
on, so a stray edit there would break your own preview with no visible
cause. You'll write one for real in Part 3, where the project is yours.

A property with no default (no `= value`) is required, checked against
`alula.yaml`'s base layer at compile time — the same "build error, not a
bootstrap surprise" guarantee `@ConfigValue`'s no-default form makes.

## The environment-variable name a key actually reads

The transform is fixed and one-way: uppercase, `.` → `_`, prefixed
`ALULA_`. `app.name` reads `ALULA_APP_NAME`; `issues.max-page-size` reads
`ALULA_ISSUES_MAX-PAGE-SIZE` — note the literal dash. Only dots are
rewritten, so a `@Settings`-derived key with more than one word in its
property name keeps its dash straight through into the variable name, and a
dash is not legal in a variable name most shells can `export`. It's a real
gap, not a rare one: `pageSize`, `signingKey`, `tokenLifetime` all produce
one. For a key shaped like that, reach for the `alula-{env}.yaml` overlay
instead of an environment variable — `ALULA_ENV` itself has no such
problem, being a single word.
