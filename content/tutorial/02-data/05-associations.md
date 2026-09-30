---
title: Associations and Loadable
description: Why an unloaded association throws instead of returning empty.
order: 5
---

```swift
@Entity("issues")
struct Issue {
    @ID var id: UUID
    var projectID: UUID
    var title: String
    var reporterID: UUID
    @BelongsTo(foreignKey: \Issue.reporterID) var reporter: Loadable<User>
}

@Entity("projects")
struct Project {
    @ID var id: UUID
    var name: String
    @HasMany(foreignKey: \Issue.projectID) var issues: Loadable<[Issue]>
}
```

`reporter` and `issues` are declared like any other property, but their
type is `Loadable<T>`, never `T` or `[T]` directly — and neither is
populated by decoding the row. Both start `.notLoaded`, carrying the
association's own name, until something explicitly preloads them (next
exercise).

## Reading one: `.get()` throws on purpose

```swift
let name = try issue.reporter.get().displayName
```

An association nobody preloaded isn't silently `nil` and isn't a lazy
query fired on first touch — it's `HangarError.notPreloaded(association:
"reporter")`, thrown the moment code tries to read through it. That's a
deliberate trade against the alternative every lazy-loading ORM makes:
lazy loading turns a missing preload into an invisible N+1 that shows up as
a production latency graph, sometimes years later. Here, a handler that
forgot to preload fails on its *first* execution — deterministically, the
same way every time, which means any test that exercises the code path
catches it before a reviewer has to.

`.optional` and `.isLoaded` are the non-throwing escape hatches, for the
places absence genuinely is fine:

```swift
if project.issues.isLoaded {
    let count = project.issues.optional?.count ?? 0
}
```

## A nullable foreign key is a nullable `Loadable`, not a special case

```swift
@BelongsTo(foreignKey: \Issue.assigneeID) var assignee: Loadable<User?>
```

`.notLoaded` still means "nobody asked yet." `.loaded(nil)` means something
different and more specific: "this was fetched, and this issue genuinely
has no assignee." Collapsing those into one `nil` is exactly the ambiguity
`Loadable` exists to avoid — which is also why it only conforms to
`Encodable`, never `Decodable`. A preloaded model serializes straight to
JSON (a loaded association becomes its value, an unloaded one becomes
`null`), but decoding that same `null` back could never tell you which of
the two it originally meant. Models come out of an application as JSON;
whatever comes in is a request type of its own, not an `Issue` with holes
in it.
