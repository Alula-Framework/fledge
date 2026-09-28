---
title: The actuator
description: Health probes everywhere; the dashboard only where you ask for it.
order: 6
---

`ActuatorModule.self` in a bootstrap's `modules:` list (§0) registers the
actuator's routes — but which of them actually answer depends on where the app
is running, and not in the way "absent in production" makes it sound at first.

```
GET /actuator/health         → {"failed":0,"modules":3,"notStarted":0,"status":"UP"}
GET /actuator/health/live    → is the process wedged?
GET /actuator/health/ready   → can it take traffic right now?
GET /actuator                → the dashboard: every module's health, every component, each readiness check
GET /actuator/info           → which build is running, and since when
```

The three health probes are registered **everywhere** the actuator is
enabled, prod included — an orchestrator needs something to probe no matter
the environment, and they're deliberately minimal enough to be safe
unauthenticated: a status and counts, no component list, no type names, no
failure text. Each answers `200` when it's `UP` and `503` otherwise, so a probe
can read the status code alone.

They answer different questions on purpose. **Liveness** fails only when a
module's service has thrown — the thing a restart can clear; a module still
starting doesn't count, or a slow start would be killed into the same slow
start forever. **Readiness** is strict: a module still starting or failed, a
dependency check failing (alula-data's pools contribute a ping, so a database
that stops answering takes the instance out of rotation), or a process that has
begun shutting down all mean no. Point a load balancer at `ready`, a restart
policy at `live`.

The dashboard and `/actuator/info` are the ones that are genuinely gone
outside development. *That's* the "unless you ask" part.

## An allowlist, not a `.prod` check

The obvious gate — "publish the dashboard unless the environment is
`.prod`" — fails open twice. Any environment name the code doesn't recognize
(a typo, `production` instead of `prod`) is not `.prod`, and neither is a
deployment that never set `ALULA_ENV` at all. Alula inverts it: only
environments *named* as development — `ALULA_ENV` set to `dev`,
`development`, `test` or `local` — get the dashboard. Everything else —
`prod`, `staging`, anything unrecognized, **and an unset `ALULA_ENV`** — gets
the health probes and nothing more. An unset `ALULA_ENV` still *loads*
`alula-dev.yaml`; the question here is whether to publish your topology, and
"nobody set the variable" isn't an answer worth acting on. The OpenAPI
document and the mail module's log-instead-of-send fallback follow the same
rule. On your own machine, `alula dev` sets `ALULA_ENV=dev` for you, and
`ALULA_ENV=dev swift run MyService` does the same by hand.

Getting an environment name wrong now costs you a dashboard, never leaks one.

The one thing that overrides this is a process environment variable, never
an `alula.yaml` key — writing `actuator: exposure:` into the file does
nothing:

```bash
ALULA_ACTUATOR_EXPOSURE=full ./MyService          # probes and dashboard, anywhere
ALULA_ACTUATOR_EXPOSURE=health_only ./MyService   # probes only, even in dev
ALULA_ACTUATOR_EXPOSURE=disabled ./MyService      # no actuator routes at all
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
`ssr` renders a plain HTML table, no CSS framework, no client-side JS;
`json` gives you the same information as a wire format a script can
consume. This is the one Part 0's `alula.yaml` already showed you,
before there was anything to say about it yet.

## Putting something in front of it

The dashboard is open unless you say otherwise — which is why it isn't
published outside development by default. Running it with `full` somewhere
anyone else can reach means requiring someone, and two keys do it:

```yaml
actuator:
  dashboard-pipelines: authenticated   # the lanes /actuator runs through
  dashboard-roles: operator, sre       # any one of these; optional
```

`dashboard-pipelines` names lanes exactly as a route's `pipelines:` does;
`authenticated` is the lane `AlulaSecurityModule` declares (see
[Authentication](/tutorial/03-intermediate/02-authentication)), so a signed-in
principal is required before the dashboard renders. `dashboard-roles` is the
same check a `roles:` route makes — `401` with no credential, `403` with the
wrong one. The health probes are never gated: an orchestrator has no
credential to present, and a probe that answers `401` restarts a healthy pod.
Startup warns about `full` outside a development environment until the
dashboard requires someone. A reverse proxy rule scoped to the path, or a
network boundary that never routes `/actuator` past your own edge, works too.
