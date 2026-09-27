---
title: Queries
description: Predicates, joins, aggregates, and projections that decode into your own types.
order: 11
category: Hangar
---

A query is a value, composed from an entity's generated `Columns`:

```swift
let urgent = Issue.where { $0.status == "open" && $0.priority == "urgent" }
    .order { $0.updatedAt.desc() }
    .limit(20)
```

`debugSQL` shows exactly what it renders to — every column listed
explicitly (never `SELECT *`), every value a `$n` placeholder, never a
literal:

```
SELECT "id", "title", "status", "priority", "updated_at", "reporter_id" FROM "issues" WHERE (("status" = $1) AND ("priority" = $2)) ORDER BY "updated_at" DESC LIMIT 20
```

## Joins, aliases, and self-joins

```swift
Issue.join(Project.self, on: { issue, project in issue.projectID == project.id })
    .select(into: Row.self) { issue, project in
        (title: issue.title, project: project.name)
    }
```

`.leftJoin` is the same shape for "every row, matched or not." A self-join
needs an alias on at least one side — Hangar's two `FROM` entries must have
distinct names, or every column reference is ambiguous:

```swift
Employee.alias("manager").join(Employee.alias("report"),
    on: { manager, report in report.managerID == manager.id })
```

Forget the alias on a genuine self-join and it fails when the query
renders, naming the exact fix. A third table joins on from any two-table
join, its closure seeing all three column sets:

```swift
Issue.join(Project.self, on: { i, p in i.projectID == p.id })
    .join(User.self, on: { _, issue, user in issue.reporterID == user.id })
```

## Aggregates and projections

```swift
struct ProjectIssueCounts: Decodable { let projectID: UUID; let issueCount: Int }

try await repo.all(
    Issue.groupBy { $0.projectID }
        .having { $0.id.count() > 10 }
        .select(into: ProjectIssueCounts.self) { i in
            (i.projectID, i.id.count())
        })
```

`select(into:)` projects straight into any `Decodable` type — not just the
entity itself — for exactly the case a full model would over-fetch: an
aggregate, a narrow read, a join's combined row.

## Reporting expressions

Grouping, aggregates and ordering take expressions, not only columns — here
over an `Incident` entity with an `openedAt`, an optional `acknowledgedAt` and
a `severity`:

```swift
struct DailyTrend: Decodable {
    let day: Date
    let opened: Int
    let critical: Int
    let medianAckSeconds: Double?
}

let utc = TimeZone(identifier: "UTC")!
let trend = try await repo.all(
    Incident.groupBy { $0.openedAt.truncated(to: .day, in: utc) }
        .select(into: DailyTrend.self) {
            (day: $0.openedAt.truncated(to: .day, in: utc),
             opened: $0.id.count(),
             critical: $0.id.count().filter($0.severity == 1),
             medianAckSeconds: $0.acknowledgedAt.interval(since: $0.openedAt).seconds.median())
        }
        .order { $0.openedAt.truncated(to: .day, in: utc).asc() })
```

`truncated(to:in:)` renders `date_trunc`, `interval(since:)` interval
arithmetic, `.filter` an aggregate `FILTER`, and `percentile`/`median` the
ordered-set aggregates. Arithmetic is methods — `adding`, `subtracting`,
`multiplied(by:)`, `divided(by:)` — rather than operators, which keeps
ordinary `Double` arithmetic fast to type-check in every file importing
Hangar.

## Combining queries

Projections of different tables into the same result type combine with
`union`, `unionAll`, `intersect` and `except`, and the combination orders by
output column, limits and runs like a query — here a feed merging
incidents with a `Deploy` entity's rows. `ColumnExpression.value(_:)`
puts a constant in a projection, so each branch can say where its rows came
from:

```swift
struct FeedItem: Decodable {
    let at: Date
    let source: String
    let summary: String
}

let feed = Incident.all.select(into: FeedItem.self) {
        (at: $0.openedAt, source: ColumnExpression.value("incident"), summary: $0.status)
    }
    .unionAll(Deploy.all.select(into: FeedItem.self) {
        (at: $0.finishedAt, source: ColumnExpression.value("deploy"), summary: $0.service)
    })
    .order("at", .desc)
    .limit(50)

let items = try await repo.all(feed)
```

A branch whose labels come in another order is lined up by label; a branch
with different labels is refused before anything runs.

## Bulk writes

One statement, however many rows match:

```swift
let closed = try await repo.update(Issue.where { $0.status == "open" }) {
    ($0.status.set(to: "closed"), $0.updatedAt.set(to: .transactionTimestamp))
}
let purged = try await repo.delete(Session.where { $0.expiresAt < .now })
```

Both return an `Int` row count — zero is a normal answer, not an error. A
query with no predicate at all deletes every row in the table; Hangar
honors that rather than second-guessing it. `set(to:)` takes a value, another
column, or an expression the server computes per row —
`$0.version.set(to: $0.version.adding(1))` renders `SET version = (version +
$1)`, so concurrent increments don't lose each other. A query carrying a
clause a single `UPDATE` or `DELETE` can't honor — `LIMIT`, `ORDER BY`,
`GROUP BY` — is refused (`HGR-QUERY-4111`) rather than run with the clause
silently dropped.

## Where to go next

- [Changesets](/guides/hangar-changesets) — validated, tracked single-row
  writes, the counterpart to the bulk writes above.
- [Associations & Preloading](/guides/hangar-preloading) — batched reads
  across related tables, without a join.
- [Transactions & Multi](/guides/hangar-transactions) — wrapping several
  writes into one unit of work.

[Part 2 of the tutorial](/tutorial/02-data) builds all of this as runnable
exercises, with `debugSQL` output shown for every query.
