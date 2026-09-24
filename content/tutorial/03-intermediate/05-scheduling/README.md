---
title: Work on a schedule
description: "@Scheduler, and running a job once when there really are several servers."
order: 5
---

```swift
import AlulaScheduler
import Foundation          // the expansion references Date — see below

@Scheduler
struct ReportJobs {
    @Inject var reports: ReportService

    @Scheduled("0 0 3 * * *")
    func nightlyRollup() async throws {
        try await reports.rollUpYesterday()
    }

    @Scheduled(every: .minutes(5))
    func refreshCache() async throws {
        await reports.warmCache()
    }
}
```

The `import Foundation` is not decoration: `@Scheduler`'s expansion refers
to `Date` (a job's scheduled instant is one), so the file needs it even
though nothing you wrote mentions it. Omit it and the error is `cannot
find 'Foundation' in scope`, pointing into macro-expanded code rather than
at any line you typed.

`@Scheduler` marks an ordinary singleton component — `@Inject` resolves
its dependencies exactly like any other type. `@Scheduled` takes either a
six-field cron expression (seconds first: `0 0 3 * * *` is 03:00 UTC every
day) or a fixed interval measured from the end of the previous run, never
wall-clock. Either way the method itself takes no parameters and returns
`Void` — there's no caller to hand it arguments, so anything it needs comes
through `@Inject` on the enclosing type instead. The cron string must be
a literal: that's what lets the build plugin validate it against the same
parser that runs it, so a malformed expression is a build error, not a job
that silently never fires.

## The problem with more than one server

Run two instances of this app and, with nothing else configured, both fire
`nightlyRollup` at 03:00 — every scheduled job runs on every node by
default, which is correct on exactly one server and wrong on a fleet.
Alula's answer isn't a distributed cron library bolted on top; it's one
narrow seam, `JobCoordinator`:

```swift
public protocol JobCoordinator: Sendable {
    func claim(job: String, scheduledFor: Date) async throws -> Bool
    func release(job: String, scheduledFor: Date) async
}
```

The contract is exactly as small as it looks: for one `(job, scheduledFor)`
pair, `claim` must return `true` in *at most one* process. Returning `true`
in none is survivable — that firing is skipped and logged; returning `true`
in two is the bug the whole mechanism exists to prevent, so an
implementation that's unsure must refuse rather than guess. With no
coordinator provided, the default always claims `true` — correct for a
single server, and exactly why the framework warns at startup if it
detects scheduled jobs and no coordinator: it's telling you which side of
that assumption you're currently on.

## The Postgres coordinator, and why it isn't an advisory lock

`alula-data`'s `PostgresJobCoordinator` is the shipped implementation —
and it deliberately isn't built on `pg_try_advisory_lock`, for the same
reason the first exercise of this part cared about connection affinity: an
advisory lock is scoped to the *session* that took it and must be released
on that same connection, but this package hands out pooled connections, so
a claim and its release would routinely land on two different ones. A
lease row sidesteps that entirely:

```sql
INSERT INTO alula_job_leases (job, scheduled_for, claimed_by, claimed_at)
VALUES ($1, $2, $3, now())
ON CONFLICT (job, scheduled_for) DO NOTHING
RETURNING job
```

`ON CONFLICT DO NOTHING` needs no connection affinity at all — the race
resolves in the database itself, where exactly one `INSERT` sees no
conflicting row and returns it, and every other server's attempt returns
nothing. The primary key is `(job, scheduled_for)`, so two servers whose
clocks differ by a second still agree on which *firing* they're contending
for, since the scheduler passes the schedule's own instant rather than
each server's local idea of "now." You wire it in by *providing* it — a
stored property on a module, which the composition root matches to
`AlulaSchedulerModule` by type:

```swift
struct AppModule: AlulaModule {
    static var dependencies: [any AlulaModule.Type] {
        [PostgresDataModule<PrimaryDataSource>.self, AlulaSchedulerModule.self]
    }

    /// Handed to `AlulaSchedulerModule`, matched by the `any JobCoordinator`
    /// type. Built from the datasource the composition root already wired, so
    /// the module reads it off the graph.
    let jobCoordinator: any JobCoordinator

    init(graph: AlulaGraph) {
        self.jobCoordinator = PostgresJobCoordinator(dataSource: graph.postgresDataSource)
    }
}
```

The explicit `any JobCoordinator` annotation is what makes the match work:
the composition root reads source text, not a conformance table, so
`let jobCoordinator = PostgresJobCoordinator(...)` — inferred type — wouldn't
be recognized as the coordinator `AlulaSchedulerModule` is looking for. This
used to be a `container.register((any JobCoordinator).self)` the scheduler
resolved at runtime, which meant a deployment that forgot it degraded
silently; providing it as a value means the missing-coordinator warning at
startup is the only place that question gets answered.

## When every node running it is actually what you want

`refreshCache` above warms an in-memory cache — exactly the case where
`.once` would be wrong, since a per-node cache needs per-node warming:

```swift
@Scheduled(every: .minutes(5), onEveryNode: true)
func refreshCache() async throws {
    await reports.warmCache()
}
```

`onEveryNode: true` skips the coordinator entirely for that one job, so it
runs on every server on its own schedule regardless of what's registered
for anything else. The default (`false`) is the one that needs a
coordinator to mean what it says on more than one server; this is the
explicit opt-out for the jobs that were never trying to be exclusive in the
first place.
