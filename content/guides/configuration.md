---
title: Configuration
description: alula.yaml, environment variables, and @ConfigValue/@Settings.
order: 3
category: Alula
---

Every Alula app resolves configuration once, at bootstrap, into an
immutable value — frozen before the container is even built, so nothing
downstream can read a value that changes mid-run. It's built from three
layers:

1. **`alula.yaml`** — defaults shared by every environment.
2. **`alula-{env}.yaml`** — an overlay for one environment, selected by
   `ALULA_ENV` (`dev` if unset; `test`, `staging`, `prod` are built in, and
   an app can define more).
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
@ConfigValue("app.maintenanceMode", default: false) var maintenanceMode: Bool
```

Absent from every layer, it's `false`; present but the wrong shape still
fails at bootstrap rather than silently keeping the default.

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

The transform is fixed and one-way: uppercase, `.` → `_`, prefixed
`ALULA_`. `app.name` reads `ALULA_APP_NAME`. Only dots are rewritten,
so a `@Settings`-derived key with more than one word in its property name
carries its dash straight into the variable name —
`posts.max-page-size` reads `ALULA_POSTS_MAX-PAGE-SIZE`, which most shells
can't `export`. For a key shaped like that, reach for the
`alula-{env}.yaml` overlay instead.

## Where to go next

- [Routing and Controllers](/guides/routing-and-controllers) — where a
  `@ConfigValue` property most often lives: a `@Controller` or `@Service`.
- [Requests & Responses](/guides/requests-and-responses) — shaping what a
  handler sends back.

[Part 1 of the tutorial](/tutorial/01-basics/09-configuration) builds this
same layering as a runnable exercise.
