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

## Three tiers

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

Each tier builds on the one before it, so nothing you learn on `skeleton`
is invalidated by the others: the `HealthController` that teaches you
`@Controller` is in all three (`demo`'s adds a second route). They are
separate starting points, though, not layers you upgrade through. A project
made from `skeleton` stays a `skeleton` project; moving it up later means
adding the next tier's pieces by hand.

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
package trait in the generated `Package.swift`. Leave `--with` off and you get
what the tier's own code needs: nothing for `skeleton`, `postgres` for
`basics`, `postgres` and `security` for `demo`; naming any replaces that
default. Nothing else is resolved: a `skeleton` project's dependency graph
really is just Alula's core and HTTP layer, nothing brought in "in case you
need it later." A
combination the tier's own code couldn't compile against — `--tier basics
--with valkey`, which leaves out the `postgres` its repository is written
against — is refused at generation time rather than emitted broken.

A trait the tier's code doesn't use yet — `valkey` on `basics`, above — is
switched on in `Package.swift` but wired into nothing, and `alula new` says so:
after the usual next steps it prints what is left to do for each one (the
product to add, the module to list, the key to set).

`alula new` also names the project after its argument: `Sources/MyService`,
`Tests/MyServiceTests`, and an executable you run with `swift run MyService`.
It finishes by printing the commands to run next — for `basics` and `demo`,
starting a Postgres and applying the migrations first.

## Why this matters before you've written anything

The alternative most frameworks choose is a single starting template with
everything wired in, disabled by config flags. Alula's tiers are a
different bet: **what you didn't ask for was never resolved, so it can
never be a build you have to explain.** A `skeleton` project's
`Package.swift` has exactly one dependency line naming exactly one trait.
That line is the whole story of what the project depends on, and it stays
that way until you change it.
