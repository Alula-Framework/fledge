---
title: Configuration
description: alula.yaml, environment variables, and @ConfigValue/@Settings.
order: 3
category: Alula
---

Every Alula app resolves configuration once, at bootstrap, into an
immutable value — frozen before any module or component is built, so nothing
downstream can read a value that changes mid-run. It's built from three
layers:

1. **`alula.yaml`** — defaults shared by every environment.
2. **`alula-{env}.yaml`** — an overlay for one environment, selected by
   `ALULA_ENV` (`dev` if unset; `test`, `staging`, `prod` are built in, and
   an app can define more). Unset loads `alula-dev.yaml` but does not
   *declare* development: the actuator dashboard, the OpenAPI document and
   the mail module's log-instead-of-send fallback appear only when
   `ALULA_ENV` is set to `dev`, `development`, `test` or `local`. `alula dev`
   sets it for you.
3. **`ALULA_*` environment variables** — always win over both files.

## One value: `@ConfigValue`

```swift
@ConfigValue("app.name") var appName: String
```

No default means required: the build plugin checks this key against
`alula.yaml`'s base layer at *compile* time, so a missing or misspelled
key is a build error naming the site, not a bootstrap-time surprise. A key
that's genuinely optional gets a default instead:

```swift
@ConfigValue("app.maintenance-mode", default: false) var maintenanceMode: Bool
```

Absent from every layer, it's `false`; present but the wrong shape still
fails at bootstrap rather than silently keeping the default. Keys are
kebab-case — `maintenance-mode`, not `maintenanceMode` — the same convention
every framework key follows.

## A related group: `@Settings`

Several keys that belong together bind once as a typed struct:

```swift
@Settings("posts")
struct PostsSettings {
    var pageSize: Int = 25
    var maxPageSize: Int = 100
}
```

```yaml
posts:
  page-size: 25
  max-page-size: 100
```

Every property name is transformed `camelCase` → `kebab-case` to build its
key — `pageSize` binds `posts.page-size`. Resolve it like any other
component:

```swift
@Inject var settings: PostsSettings
```

A property with no default is required, checked at compile time exactly
like `@ConfigValue`'s no-default form.

## The environment-variable name a key actually reads

The transform is fixed and one-way: uppercase, every character that is not a
letter or a digit becomes `_`, prefixed `ALULA_`. `app.name` reads
`ALULA_APP_NAME`, and the dash in a multi-word key goes the same way as the
dot — `posts.max-page-size` reads `ALULA_POSTS_MAX_PAGE_SIZE`, which any shell
can `export`.

Because it is one-way, `max-page-size`, `max_page_size` and `max.page.size`
all read the same variable; don't define keys that differ only there. A
missing-key error names exactly the variable the runtime reads:

```
error: [ALU-CONFIG-5004] Configuration key 'posts.max-page-size' is not set in any source (active environment: prod). Add it to alula.yaml or alula-prod.yaml, or set the ALULA_POSTS_MAX_PAGE_SIZE environment variable.
```

## Where to go next

- [Routing and Controllers](/guides/routing-and-controllers) — where a
  `@ConfigValue` property most often lives: a `@Controller` or `@Service`.
- [Requests & Responses](/guides/requests-and-responses) — shaping what a
  handler sends back.

[Part 1 of the tutorial](/tutorial/01-basics/09-configuration) builds this
same layering as a runnable exercise.
