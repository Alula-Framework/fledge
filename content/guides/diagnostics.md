---
title: When the Build Says No
description: Reading Alula's diagnostic codes, and `alula explain`.
order: 6
category: Alula
---

Alula moves as much as it can from runtime to build time: a dependency nothing
provides, two routes on one path, a configuration key no file defines. The cost
of that is a build that refuses more often, so every refusal is written to be
acted on. Each carries a stable code, points at your code rather than generated
code, and says what to do.

```
Sources/App/Reports.swift:16:24: error: [ALU-DI-1001] no module in this application provides `LabState`
    needed by:
      ExperimentService.state → LabState
    A module provides a value by holding it as a stored property with a written type.
    help: write the type of the property named below; that is what composition matches on.
    docs: https://github.com/Alula-Framework/alula/blob/main/Diagnostics/ALU-DI-1001.md
Sources/App/LabModule.swift:6:9: note: `LabModule.labState` constructs a `LabState` but has no written type, so it provides nothing — write `let labState: LabState = …`
```

## Reading one

- **The code** — `ALU-DI-1001` — is stable. It is never renumbered or reused,
  so it is safe to search for, to paste into an issue, or to mention in a
  commit message. The family says where the problem lives:

  | Family | Area |
  |---|---|
  | `ALU-DI-1xxx` | Dependency injection and the component graph |
  | `ALU-WEB-2xxx` | Controllers, routes, middleware, request binding |
  | `ALU-OAPI-3xxx` | The OpenAPI document |
  | `ALU-CONFIG-5xxx` | Configuration |
  | `ALU-SEC-6xxx` | Security and authentication composition |
  | `ALU-CMD-7xxx` | Commands |
  | `ALU-LIFE-8xxx` | Modules and lifecycle |
  | `ALU-SCHED-9xxx` | Scheduled jobs |
  | `HGR-QUERY-4xxx` | Hangar: queries Postgres would reject |
  | `ALD-…` | alula-data: cache annotations and migrations |

- **The location** is yours. A composition error points at the `@Inject` that
  needs the value, a duplicate route at the second handler. When the fix is
  somewhere else — the property that should provide the value, the first of
  two routes — a `note:` points there too, so your editor can take you to it.
- **`help:`** is the change to make. When there is exactly one right fix, as
  with a controller class that is not `final`, your editor offers it as a
  fix-it.
- **`docs:`** links the code's page: what it means, why Alula refuses it, the
  common causes, and an example.

## `alula explain`

The same pages, offline:

```bash
alula explain ALU-DI-1001      # one code's page
alula explain 1001             # the number alone is enough
alula explain                  # every code, by family
```

Copy the code however it came — `[ALU-DI-1001]` with its brackets, or in
lowercase — and it is found. A code that does not exist gets its nearest
neighbours suggested.

## At startup

Some problems can only be found when the application starts: a key that is
set in no source, because the build checks only the base file and a key can
depend on the environment; a route a module registers as a value, which the
build cannot see. Those carry the same code the build would have used:

```
alula: could not start.
error: [ALU-CONFIG-5004] Configuration key 'mail.host' is not set in any source (active environment: prod). Add it to alula.yaml or alula-prod.yaml, or set the ALULA_MAIL_HOST environment variable.
    docs: https://github.com/Alula-Framework/alula/blob/main/Diagnostics/ALU-CONFIG-5004.md
```

A problem keeps its code wherever it is found, so one search finds one
explanation. And a command that runs and fails says so — `alula: command
'sync-inventory' failed.` — rather than claiming the application could not
start.

## Every code

The [index of Alula's codes](https://github.com/Alula-Framework/alula/tree/main/Diagnostics)
lists every one with its title. Hangar's and alula-data's live with those
packages, and `alula explain` points at them.
