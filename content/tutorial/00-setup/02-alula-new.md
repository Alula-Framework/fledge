---
title: alula new, and the tier/trait model
description: Three starting points, and how dependencies stay opt-in.
order: 2
---

Every Alula project starts the same way:

```bash
alula new MyService
```

This gives you the smallest real thing: configuration, dependency
injection, an HTTP server, and the operational endpoints. No database, no
real-time layer, no cache — those aren't missing pieces, they're absent
dependencies. You add them by asking for more.

## Three tiers, and they nest

```bash
alula new MyService                  # skeleton
alula new MyService --tier basics    # + entities, migrations, a repository, CRUD
alula new MyService --tier demo      # + PubSub, Channels, Presence, caching, auth
```

| Tier | For | Adds |
|---|---|---|
| `skeleton` | A new service | Configuration, DI, HTTP, health endpoints |
| `basics` | A service with a database | entities, migrations, a repository, CRUD |
| `demo` | Reading, not starting from | PubSub, Channels, Presence, caching, auth, the full query tour |

That "adds" is literal, not a summary: `skeleton`'s files are a subset of
`basics`', and `basics`' a subset of `demo`'s, checked in the framework's
own CI. Nothing you learn on `skeleton` gets invalidated when you move up a
tier — the file that taught you `@Controller` is still there, unchanged,
in `demo`.

`demo` is marked "for reading" on purpose: it is the widest tour of what
Alula offers, not the tier you should build a new service from. Most real
services start at `skeleton` or `basics` and add capabilities one at a
time, the way this tutorial does.

## Dependencies are named, not implied

The tier chooses the code; `--with` chooses what it depends on:

```bash
alula new MyService --tier basics --with postgres,valkey
```

`postgres`, `valkey`, and `security` are the options, and each maps to a
package trait in the generated `Package.swift`. Naming none of them
resolves none of them — a `skeleton` project's dependency graph really is
just Alula's container and HTTP layer, nothing brought in "in case you
need it later." A combination the tier's own code couldn't compile against
is refused at generation time rather than emitted broken.

## Why this matters before you've written anything

The alternative most frameworks choose is a single starting template with
everything wired in, disabled by config flags. Alula's tiers are a
different bet: **what you didn't ask for was never resolved, so it can
never be a build you have to explain.** A `skeleton` project's
`Package.swift` has exactly one dependency line naming exactly one trait.
That line is the whole story of what the project depends on, and it stays
that way until you change it.
