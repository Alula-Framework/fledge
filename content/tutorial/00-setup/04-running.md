---
title: Running it locally
description: swift run, swift test, and what this site's editor will map to.
order: 4
---

From inside the project directory:

```bash
swift run
```

The first build resolves dependencies and compiles the framework, which
takes longer than every build after it — Swift's incremental compiler
caches aggressively, so the second `swift run` after a one-line change is
seconds, not minutes. When it's up:

```bash
curl http://127.0.0.1:8080/
# App is flying
```

That's `HealthController.index`, reading `app.name` out of `alula.yaml`
and returning it. Change the `app.name` value, restart, curl again — the
response changes. That round trip is the one you'll repeat, in some form,
for every exercise in this tutorial.

## Tests

```bash
swift test
```

`Tests/AppTests/HealthControllerTests.swift` exercises the same route
without a real socket — `AlulaWebTesting`'s `TestClient` dispatches
through the exact same `Request`/`Response` types your controller does,
skipping the transport layer entirely rather than routing through an
in-process stand-in for it. Routing, middleware, and dependency injection
all still run for real; only the network is absent. A controller test
ends up reading like calling a function, not like standing up a server and
tearing it down. You'll see this pattern again, in more depth, in
[Testing](/guides/testing) once there's more than one route to test.

## What this site's editor maps to

The exercises after this one run in an embedded editor rather than your
terminal — but they run the same two commands underneath. When an
exercise says "Run," it is doing `swift build` and either `swift run` or
`swift test` against a real, warm Swift workspace, the same as you just
did by hand. Nothing about the framework changes between here and there;
only where the terminal lives does.

If the in-browser editor is ever unavailable — rate-limited, or simply
not deployed yet for a given exercise — every exercise is also a
downloadable `alula new`-shaped project. Reading and running it locally,
the way this page just walked through, always works.
