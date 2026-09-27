---
title: Repo and first queries
description: A query is a value. Nothing runs until a Repo executes it.
order: 2
---

```swift
let query = Issue.where { $0.status == "open" }
    .order { $0.updatedAt.desc() }
    .limit(10)

let issues = try await repo.all(query)
```

`Issue.where { }` is sugar for `Issue.all.where { }` — `Issue.all` is the
unfiltered query every chain starts from, whether you write it or not.
Every method on it — `where`, `order`, `limit` — returns a new `Query`
rather than changing anything, which is what makes the next part true.

## Nothing happens until `repo.all`/`repo.one`

`query` above is a value: building it runs no SQL at all. That means it can
be built in pieces, held onto, and reused — composing from a shared base
never disturbs the base itself:

```swift
let base = Issue.where { $0.status == "open" }

let recent = base.order { $0.updatedAt.desc() }.limit(10)
let urgent = base.where { $0.priority == "urgent" }
```

`recent` and `urgent` both start from `base`; neither mutates it, so
`base` is exactly as usable after both lines as before them. The `Repo` is
what actually reaches the database, and it comes in exactly two shapes
matched to what you're asking for:

```swift
let issues: [Issue] = try await repo.all(query)     // every matching row
let issue: Issue? = try await repo.one(
    Issue.where { $0.id == id })                     // zero or one
```

`one` returns `nil` for zero matches — "no issue has that id" is an
entirely normal outcome, not an error. It throws only when a query meant to
identify a single row finds *more than one*, which is never legitimate: two
rows matching a query built to find one is a bug worth surfacing loudly,
not a `nil` indistinguishable from zero. The error says so, with a code you
can look up:

```
[HGR-QUERY-4103] one(...) on "issues" matched more than one row; use all(...) or add a narrower predicate. See https://github.com/Alula-Framework/hangar/blob/main/Diagnostics/HGR-QUERY-4103.md
```
