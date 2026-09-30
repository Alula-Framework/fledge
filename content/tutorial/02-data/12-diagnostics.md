---
title: Diagnostics and EXPLAIN
description: "Closing the loop on the preloading lesson: catching an N+1 you missed."
order: 12
---

`debugSQL` (exercise 3) shows what a query renders to. It can't say whether
that statement is actually slow, or why. Two different tools answer those,
and neither one is on by default.

## Why a statement is slow: `EXPLAIN`

```swift
let plan = try await repo.explain(
    Issue.where { $0.reporterID == id }.order { $0.createdAt.desc() },
    mode: .analyze)
print(plan)
```

`.plan` (the default) asks Postgres to estimate without running anything —
safe against absolutely any query, since nothing executes. `.analyze` runs
it for real and reports what actually happened: real row counts, real
timings, whether the planner's estimate matched reality. The divergence
between the two is usually the whole diagnosis — an index that isn't being
used, a row estimate that's wrong by three orders of magnitude. Because
`.analyze` executes, `explain` refuses it for anything that may write
(`HGR-QUERY-4115`) instead of performing the write. (There's also
`explain(_:mode:)` for a raw `SQLFragment`, for statements the builder
doesn't express. It plans a write too, with `.plan`, on the primary rather
than a read replica.)

The plan comes back as plain text, one line per node, exactly what `psql`
would show — deliberately not parsed into a structured type. A plan is
something you read, not something a program branches on, and a parsed
form would be one more thing to keep in sync with Postgres's own output
across versions.

## Catching a missed preload: repeated-query detection

`EXPLAIN` diagnoses one statement you already suspect. This catches a
*shape* you didn't know to suspect:

```swift
var repo = Repo(client: pool, logger: logger)
repo.diagnostics = .recommended   // 200ms slow-query threshold, 20 repeats

try await repo.detectingRepeatedQueries {
    try await renderDashboard()
}
```

If the same statement shape runs 20 or more times inside that closure, the
logger gets a warning naming the SQL, the count, and the fix: *"the same
statement ran N times in one unit of work — a preload or a join usually
replaces this."* That's the exact failure mode exercise 6 exists to
prevent — an association read one parent at a time instead of batched —
except this is the safety net for the time a `.preload` genuinely got
missed, in code nobody thought to suspect until the count made it obvious.

Both diagnostics are opt-in on purpose: a slow-query threshold that fires
on every request is noise nobody reads, and a repeat threshold nobody set
never fires at all. `repo.diagnostics = .recommended` is a reasonable
default to start from, not the only correct number.
