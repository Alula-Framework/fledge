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
Sources/MyService/Reports.swift:16:24: error: [ALU-DI-1001] no module in this application provides `LabState`
    needed by:
      ExperimentService.state → LabState
    A module provides a value by holding it as a stored property with a written type.
    help: write the type of the property named below; that is what composition matches on.
    docs: https://github.com/Alula-Framework/alula/blob/main/Diagnostics/ALU-DI-1001.md
Sources/MyService/LabModule.swift:6:9: note: `LabModule.labState` constructs a `LabState` but has no written type, so it provides nothing — write `let labState: LabState = …`
```

## Reading one

- **The code** — `ALU-DI-1001` — is stable. It is never renumbered or reused,
  so it is safe to search for, to paste into an issue, or to mention in a
  commit message. The family says where the problem lives:

  | Family | Area |
  |---|---|
  | `ALU-DI-1xxx` | Dependency injection and the component graph |
  | `ALU-WEB-2xxx` | Controllers, routes, middleware, request binding — and a server that cannot listen |
  | `ALU-OAPI-3xxx` | The OpenAPI document |
  | `ALU-CONFIG-5xxx` | Configuration, at build time and at startup |
  | `ALU-SEC-6xxx` | Security and authentication composition |
  | `ALU-CMD-7xxx` | Commands |
  | `ALU-LIFE-8xxx` | Modules and lifecycle, including why a running application stopped |
  | `ALU-SCHED-9xxx` | Scheduled jobs |
  | `HGR-QUERY-40xx` | Hangar, at build time: a query Postgres would reject |
  | `HGR-QUERY-41xx` | Hangar, when a query runs: a rolled-back transaction, a `one` that matched several rows, an association read without a preload, … |
  | `ALD-CACHE-1xxx` | alula-data: `@Cacheable`, `@CachePut` and `@CacheEvict` |
  | `ALD-DATA-1xxx` | alula-data: a data source that could not connect at startup |
  | `ALD-MIGRATE-2xxx` | alula-data: migration files |

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

Hangar's and alula-data's pages live with those packages, which release on
their own, so for their codes `alula explain` says whose code it is and prints
the page's address instead of the page:

```bash
alula explain HGR-QUERY-4103
# HGR-QUERY-4103 is a Hangar query diagnostic. Its page:
# https://github.com/Alula-Framework/hangar/blob/main/Diagnostics/HGR-QUERY-4103.md
```

The number-alone shorthand is for Alula's own codes; write Hangar's and
alula-data's out in full.

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

The variable it names is the one the runtime reads: every character of the key
that is not a letter or a digit becomes `_`, so `pubsub.node-id` is
`ALULA_PUBSUB_NODE_ID`.

A port already in use is `ALU-WEB-2010`, naming the address and what to change,
and a database that refused the connection is alula-data's `ALD-DATA-1001`,
naming the data source, host and port — never the password. A problem keeps its
code wherever it is found, so one search finds one explanation. And a command
that runs and fails says so — `alula: command 'sync-inventory' failed.` —
rather than claiming the application could not start; an unknown command name
is `ALU-CMD-7002`, with the list of commands there are.

## After it started

"Could not start" is reserved for a start that did not complete. An
application that served for hours and then stopped says so, how long it had
been up, and which module ended it:

```
alula: stopped after running 3d 4h 12m: FeedModule failed.
error: [ALU-LIFE-8005] FeedModule failed after running 3d 4h 12m
    the provider feed closed
    docs: https://github.com/Alula-Framework/alula/blob/main/Diagnostics/ALU-LIFE-8005.md
```

The line under the diagnostic is the module's own error, unchanged. A module
whose service *returned* while the application was running — a `for await`
over a stream that finished, say — is `ALU-LIFE-8006`:

```
alula: stopped after running 4m 07s: FeedModule's service ended on its own.
error: [ALU-LIFE-8006] FeedModule's service returned without throwing
    A module's service runs until the application shuts down, unless the module
    declares `serviceCompletion: .endsApp` for a bounded job. Returning early
    stops the application.
    help: look for a loop that ended or a stream that finished, or declare `serviceCompletion: .endsApp` if the service is a bounded job.
    docs: https://github.com/Alula-Framework/alula/blob/main/Diagnostics/ALU-LIFE-8006.md
```

A graceful shutdown that runs past `lifecycle.shutdown-timeout-seconds` is
`ALU-LIFE-8004`: `alula: shutdown timed out.`, the timeout, and the modules that
were still running when they were cancelled. It exits 1, not 0, so a process
manager can tell it from a clean stop.

## When a query runs

Hangar's runtime errors lead with their code and end with their page, so a log
line is enough to look one up:

```
[HGR-QUERY-4103] one(...) on "issues" matched more than one row; use all(...) or add a narrower predicate. See https://github.com/Alula-Framework/hangar/blob/main/Diagnostics/HGR-QUERY-4103.md
```

`HGR-QUERY-4101` is the one worth knowing before it finds you: a statement
inside `transaction { }` failed, the body caught the error and carried on, and
the `COMMIT` was answered with a rollback. Hangar reports that as an error
instead of as success. A column or table the database does not have carries a
hint, `[HGR-QUERY-4114]`, pointing at migrations that have not been run against
that database.

Code that needs to react to one of these should match the `HangarError` case or
its `code`, not the description's text.

## Every code

The [index of Alula's codes](https://github.com/Alula-Framework/alula/tree/main/Diagnostics)
lists every one with its title. Hangar's live in
[Hangar's `Diagnostics/`](https://github.com/Alula-Framework/hangar/tree/main/Diagnostics)
and alula-data's in
[alula-data's](https://github.com/Alula-Framework/alula-data/tree/main/Diagnostics).
