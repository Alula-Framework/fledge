---
title: "Hangar: Getting Started"
description: Models are structs, queries are values, and a typo in a column name is a compile error.
order: 10
category: Hangar
---

Hangar is a type-safe query layer for PostgreSQL, built directly on
PostgresNIO — no runtime reflection, no string-keyed column access. You
declare a model, and the same declaration gives you a typed query builder,
a typed insert, and a typed update.

## Declaring a model

```swift
import Hangar

@Entity("issues")
struct Issue {
    @ID var id: UUID
    var title: String
    var status: String
    var priority: String
    var updatedAt: Date
    var reporterID: UUID
    @BelongsTo(foreignKey: \Issue.reporterID) var reporter: Loadable<User>
}
```

`@Entity("issues")` names the table. Every plain stored property becomes a
column automatically — `updatedAt` maps to `updated_at` on its own,
snake_case being the default column-naming convention — and you override
one only when a table doesn't follow it, with an explicit
`@Column("legacy_name")`. `@ID` marks the primary key. None of this is
reflection: the macro expands at compile time into a `Columns` type
carrying real, typed keypath-like accessors, which is what makes the next
part possible.

## A query is a value

```swift
let urgent = Issue.where { $0.priority == "urgent" }
    .order { $0.updatedAt.desc() }
    .limit(20)
```

Nothing executes yet. `urgent` is a `Query<Issue, Issue>` — a value you can
pass around, store, extend, or hand to a function, and building it further
never mutates what it was built from:

```swift
let base = Issue.where { $0.status == "open" }
let recent = base.order { $0.updatedAt.desc() }.limit(10)
let mine = base.where { $0.reporterID == currentUserID }   // `base` is unchanged
```

`$0.priority == "urgent"` is not a string template — `$0` is the generated
`Columns` value, `.priority` is a real property access, and `==` is a real
operator overload building a `Predicate`. Misspell `priority` and the
build fails at that line, not at 2am when the query finally runs against
production.

## Running it

A query does nothing until a `Repo` runs it:

```swift
let repo = Repo(client: postgresClient, logger: logger)
let issues: [Issue] = try await repo.all(urgent)
```

`repo.one(query)` returns at most one row: `nil` for zero matches, the row
for exactly one, and a thrown `HangarError.tooManyRows` for more than
one — `[HGR-QUERY-4103]`, like every error Hangar raises when a query runs,
leading with a code that has a page. Zero is a legitimate outcome — "no issue has that id" is completely
ordinary — but two rows matching a query you expected to identify a
single one is never legitimate, and `one` refuses to silently pick the
first and hide that something's wrong:

```swift
guard let issue = try await repo.one(Issue.where { $0.id == id }) else {
    throw HTTPError(.notFound, "no such issue")
}
```

## Seeing the SQL

Every query can show you exactly what it renders to, with no server
involved:

```swift
print(urgent.debugSQL)
// SELECT "id", "title", "status", "priority", "updated_at", "reporter_id" FROM "issues" WHERE ("priority" = $1) ORDER BY "updated_at" DESC LIMIT 20
```

`debugSQL` never contains a bound value — `$1`, `$2` are placeholders, the
same ones sent over the wire. That makes it safe to log, and it's the
single best debugging habit Hangar rewards: if a query returns the wrong
rows, `.debugSQL` almost always shows you why before you've touched a
debugger.

## Where to go next

- [Queries](/guides/hangar-queries) — predicates, joins, aggregates, and
  the projection shapes that decode straight into your own types.
- [Changesets](/guides/hangar-changesets) — validated, tracked writes:
  Hangar's answer to "what actually changed, and was it allowed to?"
- [Associations & Preloading](/guides/hangar-preloading) — why an
  association you forgot to load throws instead of quietly returning
  nothing, and how batched preloading avoids N+1 without a SQL join.

If you'd rather work through this interactively, [Part 2 of the
tutorial](/tutorial/02-data) builds the same ideas as runnable exercises,
with `debugSQL` output shown for every query as you write it.
