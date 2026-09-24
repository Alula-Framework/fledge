---
title: The actuator
description: Health, info, and metrics — absent entirely in production unless you ask.
order: 6
---

`ActuatorModule.self` in a bootstrap's `modules:` list (§0) registers two
routes — but which of them actually answer depends on where the app is
running, and not in the way "absent in production" makes it sound at
first.

```
GET /actuator/health   → {"status": "UP", "modules": 3, "failed": 0, "notStarted": 0}
GET /actuator          → the full topology: every module's health, every registered bean
```

`/actuator/health` is registered **everywhere**, prod included — an
orchestrator needs something to probe no matter the environment, and it's
deliberately minimal enough to be safe unauthenticated: an overall status
and per-module up/down counts, no component list, no type names, no
failure text. It answers `200` when every module started and stayed up,
`503` otherwise, so a probe can read the status code alone.

`/actuator` — the full dashboard, every registered bean grouped by layer —
is the one that's genuinely gone outside development. *That's* the "unless
you ask" part.

## An allowlist, not a `.prod` check

The obvious gate — "publish the dashboard unless the environment is
`.prod`" — has a real failure mode: an unset `ALULA_ENV` resolves to
`dev`, and any environment name the code doesn't recognize (a typo,
`production` instead of `prod`) is *also* not `.prod`, so both would have
published the dashboard by accident. Alula inverts it: only environments
*known* to be development (`dev`, `development`, `test`, `local`) get the
dashboard; everything else — `prod`, `staging`, or anything unrecognized —
gets the health probe and nothing more. Getting an environment name wrong
now costs you a dashboard, never leaks one.

The one thing that overrides this is a process environment variable, never
a `alula.yaml` key — the exposure decision has to be made before
`Configuration` is even resolvable:

```bash
ALULA_ACTUATOR_EXPOSURE=full ./App     # dashboard, anywhere
ALULA_ACTUATOR_EXPOSURE=disabled ./App # neither route, anywhere
```

An unrecognized value throws rather than silently picking a side — a typo
in the setting that controls disclosure should stop the app, not quietly
choose for you.

## The one config key that *is* ordinary

```yaml
actuator:
  format: json   # or the default, "ssr"
```

`actuator.format` is a normal, layered `alula.yaml`/env-var key —
`.ssr` renders a plain HTML table, no CSS framework, no client-side JS;
`.json` gives you the same information as a wire format a script can
consume. This is the one Part 0's `alula.yaml` already showed you,
before there was anything to say about it yet.

## Putting something in front of it

The dashboard, wherever it's enabled, is unauthenticated by design — this
module reports what your application is made of, and disclosure is a
decision the actuator deliberately leaves to you rather than guessing at.
It doesn't authenticate anything itself, and doesn't pretend to: running
`full` somewhere reachable by anyone else means putting something in front
of it yourself — `RequireAuthentication` in the default pipeline, a
reverse proxy rule scoped to the path, or a network boundary that never
routes `/actuator` past your own edge at all. Which one fits depends on
whether anything else on the default lane should stay open to the public;
the module's only promise is that it won't decide that for you.
