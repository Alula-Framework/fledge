---
title: Bulk insert, update, delete
description: One statement across every matching row, with the count returned.
order: 10
---

Three operations, each one statement regardless of how many rows it
touches:

```swift
let stored = try await repo.insert(rows.map(Issue.init))
```

Usually one statement for however many rows — not one insert per element.
Postgres caps a statement at 65,535 bound parameters, so a batch too large for
one is split into several, run inside a single transaction; either way every
row lands, or on any constraint violation, none do. (A statement-level trigger
fires once per chunk, which is the one place the split shows.) Returned rows
come back in input order, so `stored[i]` still corresponds to `rows[i]`.

## Updating a query's worth of rows at once

```swift
let closed = try await repo.update(Issue.where { $0.status == "in_progress" }) {
    ($0.status.set(to: "closed"), $0.updatedAt.set(to: Date()))
}
```

`.set(to:)` is typed against its column, so assigning an `Int` to a
`String` column is a compile error the same way a mistyped `where` predicate
would be. It takes a value — the same for every matching row — or an
expression the server computes per row: `$0.version.set(to:
$0.version.adding(1))` renders `SET "version" = ("version" + $1)`, so twenty
concurrent increments add twenty; `set(to: $0.otherColumn)` copies a column;
`set(to: .transactionTimestamp)` writes the server's `now()`. Arithmetic is
methods — `adding`, `subtracting`, `multiplied(by:)`, `divided(by:)` — not
operators. Anything a row's new value needs from outside the database still
means fetching and writing rows one at a time. The return value
is a plain `Int`, the row count — zero is a completely normal answer, not
a sign anything went wrong.

## Deleting a query's worth of rows

```swift
let purged = try await repo.delete(Issue.where { $0.status == "closed" && $0.updatedAt < cutoff })
```

Same shape, same `Int` count back. The sharp edge worth knowing before you
reach for it: a query with no predicate at all deletes **every row in the
table**. `Issue.all` means all of them, and `repo.delete` honors that
rather than second-guessing it — there's no separate "are you sure"
mechanism standing between a missing `.where { }` and an empty table.

Both bulk `update` and `delete` reject a query carrying clauses a single
`UPDATE`/`DELETE` statement can't express — `LIMIT`, `OFFSET`, `ORDER BY`,
`GROUP BY`, `HAVING`, `DISTINCT` — rather than silently dropping them and
writing more rows than the query looked like it asked for.
