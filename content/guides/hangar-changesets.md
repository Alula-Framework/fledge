---
title: Changesets
description: "Validated, tracked writes: Hangar's answer to Ecto.Changeset."
order: 12
category: Hangar
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

`Changeset(Issue.self)` starts an **insert** — no original row, so every
`change` is dirty by definition. `Changeset(original: existingIssue)`
starts an **update**, and the distinction matters downstream:
`repo.insert` and `repo.update` both take a `Changeset<Model>` and return
the materialized row.

## Validation only looks at what changed

```swift
Changeset(original: issue)
    .change(\.title, "")
    .validate(\.title, .length(1...200))
    .errors    // [title: length must be within 1...200]
```

A field nobody touched in this changeset isn't re-validated — unchanged
data already passed this rule (or an earlier one) when it was first
written, so a row that predates a stricter rule stays editable for every
field except the one the new rule actually governs.
`.validateRequired(_:)` is the exception: it checks the field's *effective*
value, since "is this present" has to hold regardless of whether this
changeset touched it.

Built-in rules beyond `.length`: `.email`, `.matches(_:)`,
`.range(_:)`, `.oneOf(_:)`, and a `.custom(message:) { }` escape hatch.

## `repo.insert`/`repo.update` validate for you

The `guard changeset.isValid` above is a chance to answer with field
errors *before* attempting a write — not a requirement. `repo.insert(_:)`
and `repo.update(_:)` both call the changeset's own validation internally
and throw `ChangesetValidationError` if it fails, so skipping the manual
check is safe:

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
body wants, without hand-rolling `Dictionary(grouping:)` over `.errors`.

## Where to go next

- [Queries](/guides/hangar-queries) — bulk writes, for "the same values,
  every matching row" instead of a multi-step unit of work.
- [Associations & Preloading](/guides/hangar-preloading) — reading related
  rows back out once they're written.

[Part 2 of the tutorial](/tutorial/02-data/04-changesets) builds this same
material as a runnable exercise.
