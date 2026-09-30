---
title: Changesets
description: Casting, validation, error shapes, and changeset-driven writes.
order: 4
---

A `Changeset` sits between decoded input and a write, tracking what
actually changed and accumulating validation failures before anything
reaches the database:

```swift
let changeset = Changeset(Issue.self)
    .change(\.title, body.title)
    .change(\.status, "open")
    .validate(\.title, .length(1...200))

guard changeset.isValid else {
    return try Response.json(changeset.messagesByField, status: .unprocessableContent)
}

let issue = try await repo.insert(changeset)
```

`Changeset(Issue.self)` starts an **insert** changeset — no original row, so
every `change` is dirty by definition. `Changeset(original: existingIssue)`
starts an **update** instead, and the distinction matters downstream:
`repo.insert` and `repo.update` both take a `Changeset<Issue>` and return
the materialized `Issue`, but which one you call depends on which kind you
built.

## Validation only looks at what changed

```swift
Changeset(original: issue)
    .change(\.title, "")
    .validate(\.title, .length(1...200))
    .errors    // [title: length must be within 1...200]
```

`.validate(_:_:)` checks a field's *recorded change* — a field nobody
touched in this changeset isn't re-validated, because unchanged data
already passed this rule (or an earlier one) when it was first written. A
row that predates a stricter rule stays editable for every field except the
one the new rule actually governs, rather than becoming un-savable the
moment validation logic evolves. `.validateRequired(_:)` is the one
exception worth knowing: it checks the field's *effective* value, since
"is this present" has to hold regardless of whether this changeset touched
it.

Built-in rules beyond `.length` cover the other common shapes —
`.email`, `.matches(_:)`, `.range(_:)`, `.oneOf(_:)` — and a
`.custom(message:) { }` escape hatch for anything specific to your own data.

## `repo.insert`/`repo.update` validate too — you don't have to remember to

The `guard changeset.isValid` above is optional, not load-bearing:
`repo.insert(_:)` and `repo.update(_:)` both call `validatedChanges()`
themselves before anything reaches the wire, and throw the same
`ChangesetValidationError` an invalid changeset would produce. Skipping the
manual check is safe — it costs you the chance to answer with field errors
*before* attempting a write, nothing more:

```swift
do {
    let issue = try await repo.insert(changeset)
    return try Response.json(issue, status: .created)
} catch let error as ChangesetValidationError {
    return try Response.json(error.messagesByField, status: .unprocessableContent)
}
```

`messagesByField` groups by column name on either path —
`["title": ["length must be within 1...200"]]` — the shape a JSON error
body wants, without hand-rolling `Dictionary(grouping:)` over `.errors`
yourself. Which of the two shapes you reach for is mostly about whether a
failed validation should look different from any other write failure in
your handler; the safety is identical either way.
