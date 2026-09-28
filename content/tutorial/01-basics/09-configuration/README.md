---
title: Configuration
description: alula.yaml, environment variables, and @Settings.
order: 9
---

Bootstrap's first step (§1) was `Configuration.load()`, resolving three
layers into one immutable value — frozen before any module or component is
built, so nothing downstream can read a config value that changes mid-run:

1. **`alula.yaml`** — defaults shared by every environment.
2. **`alula-{env}.yaml`** — an overlay for one environment, selected by
   `ALULA_ENV` (`dev` if unset; `test`, `staging`, and `prod` are built in,
   and an app can define more). `ALULA_ENV=staging` loads
   `alula-staging.yaml` on top of the base file. Unset loads the `dev` file,
   but it does not *declare* development: the surfaces only a developer
   should see — the actuator dashboard, the OpenAPI document, mail logged
   instead of sent — need `ALULA_ENV` actually set to `dev` (or `development`,
   `test`, `local`). `alula dev` sets it for you.
3. **`ALULA_*` environment variables** — always win over both files.

## One value: `@ConfigValue`

The anatomy exercise (§3) used the required form —
`@ConfigValue("app.name")`, a build error if `app.name` is missing from
`alula.yaml`. A key that's genuinely optional gets a default instead:

```swift
@ConfigValue("app.maintenance-mode", default: false) var maintenanceMode: Bool
```

— which is exactly the property the middleware exercise's `MaintenanceGate`
declared, without naming it yet. Absent from every layer, it's `false`;
present but the wrong shape (a string where a `Bool` was expected) still
fails at bootstrap rather than silently keeping the default. The key is
`maintenance-mode`, not `maintenanceMode`: keys are kebab-case, like every
key Alula and alula-data read.

**Try both forms together** in your own project, with a new controller:

```swift
@Controller
struct ConfigController {
    @ConfigValue("app.name") var appName: String
    @ConfigValue("app.maintenance-mode", default: false) var maintenanceMode: Bool
    @ConfigValue("app.greeting", default: "hello") var greeting: String

    @GetRoute("/config")
    func show(_ context: RequestContext) -> String {
        "name=\(appName) maintenance=\(maintenanceMode) greeting=\(greeting)"
    }
}
```

```
name=MyService maintenance=false greeting=hello
```

`app.name` came from `alula.yaml`. The other two aren't in any layer at
all — they're their defaults, and the app started anyway, which is the
entire difference between the two forms.

Now break it on purpose: change `"app.name"` to `"app.nam"` and rebuild.
It doesn't start and then fail; it doesn't build at all:

```
Sources/MyService/Controllers/ConfigController.swift:6:1: error: [ALU-CONFIG-5004] configuration key 'app.nam' is not in alula.yaml, and ConfigController has no default for it
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

Add the `issues:` block to your project's `alula.yaml` and the struct beside
your controllers, and `/issues` answers `page size: 25`; change the file,
restart, and it follows.

A property with no default (no `= value`) is required, checked against
`alula.yaml`'s base layer at compile time — the same "build error, not a
bootstrap surprise" guarantee `@ConfigValue`'s no-default form makes.

## The environment-variable name a key actually reads

The transform is fixed and one-way: uppercase, every character that is not a
letter or a digit becomes `_`, prefixed `ALULA_`. `app.name` reads
`ALULA_APP_NAME`; `issues.max-page-size` reads `ALULA_ISSUES_MAX_PAGE_SIZE` —
the dash goes the same way as the dot, so every key, however many words its
property name has, is a variable any shell can `export`:

```bash
ALULA_ISSUES_PAGE_SIZE=50 ALULA_APP_MAINTENANCE_MODE=true swift run MyService
```

One-way means `max-page-size`, `max_page_size` and `max.page.size` all land on
the same variable, so don't define keys that differ only in their punctuation.
When a key is missing at startup, the error names the variable to set, spelled
exactly the way the runtime reads it.
