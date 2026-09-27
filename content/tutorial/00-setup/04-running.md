---
title: Running it locally
description: swift run, swift test, and where the rest of the exercises run.
order: 4
---

From inside the project directory:

```bash
swift run MyService
```

The first build resolves dependencies and compiles the framework, which
takes longer than every build after it — Swift's incremental compiler
caches aggressively, so the second `swift run` after a one-line change is
seconds, not minutes. When it's up:

```bash
curl http://127.0.0.1:8080/
# MyService is flying
```

That's `HealthController.index`, reading `app.name` out of `alula.yaml`
and returning it. Change the `app.name` value, restart, curl again — the
response changes. That round trip is the one you'll repeat, in some form,
for every exercise in this tutorial.

## Tests

```bash
swift test
```

`Tests/MyServiceTests/HealthControllerTests.swift` exercises the same route
without a real socket — `AlulaWebTesting`'s `TestClient` dispatches
through the exact same `Request`/`Response` types your controller does,
skipping the transport layer entirely rather than routing through an
in-process stand-in for it. Routing, middleware, and dependency injection
all still run for real; only the network is absent. A controller test
ends up reading like calling a function, not like standing up a server and
tearing it down. You'll see this pattern again, in more depth, in
[Testing](/guides/testing) once there's more than one route to test.

## Where the exercises run

From here on, the exercises run where this one did: in a project of your own,
made with `alula new`, with the same `swift run` and `swift test`. Each one
names the tier to start from and the files it touches, and ships a solution
that the site's CI builds against the current `alula new` templates, so what
you read is what compiles.

The exception is Part 2, on Hangar and Changeset. Its exercises are one file
each and run in the browser — an editor, a real compile, real output, and
`debugSQL` printing the SQL beside the Swift that produced it.
