---
title: Joins, aliases, self-joins
description: Two-table, three-table, and the same table joined to itself.
order: 7
---

```swift
let rows = try await repo.all(
    Issue.join(Project.self, on: { issue, project in issue.projectID == project.id })
        .select(into: Row.self) { issue, project in
            (title: issue.title, project: project.name)
        })
```

`.join`'s closure receives both sides' typed columns — `issue.projectID`,
not a string, so a typo in either name is the same compile error a typo in
a single-table `where` would be. `.leftJoin` is the identical shape for
"every issue, matched or not" instead of "only issues with a project"
(every issue has one here, but the shape matters the moment it doesn't).

## The same table, twice

A join needs its two `FROM` entries to have distinct names — obvious for
`Issue` and `Project`, impossible by default for `Employee` joined to
`Employee`, since every column reference would be ambiguous. `.alias(_:)`
is how you give one side (or both) a name of its own:

```swift
Employee.alias("manager").join(Employee.alias("report"),
    on: { manager, report in report.managerID == manager.id })
```

Forget the alias and join a table to itself anyway, and it fails when the
query renders — not a generic ambiguity error, but one naming the exact fix:

```
[HGR-QUERY-4007] This joins Employee to itself, and a self-join needs an alias
on at least one side: both sides are named "employees", so every column would
be ambiguous. Write Employee.alias("parent").join(Employee.alias("child"), on: ...).
```

Closures after an aliased join see alias-qualified columns throughout, so
`.where { manager, _ in manager.title == "VP" }` keeps working exactly like
it would on an unaliased join.

## A third table

Joining again on a two-table `JoinedQuery` gives its closure all three
column sets, in order:

```swift
Issue.join(Project.self, on: { i, p in i.projectID == p.id })
    .join(User.self, on: { _, project, user in project.ownerID == user.id })
    .select(into: Row.self) { i, p, u in (title: i.title, owner: u.displayName) }
```

This is ordinary generics — `JoinedQuery3<A, B, C, Result>` — rather than a
variadic form that joined an arbitrary number of tables. Three tables is
what a real query needs often enough to deserve its own type; a query
needing a fourth reaches for a subquery or a second round trip instead of
a `JoinedQuery4` nobody asked for.
