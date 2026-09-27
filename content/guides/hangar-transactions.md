---
title: Transactions & Multi
description: Savepoints, isolation levels, retry-on-serialization-failure, and Multi.
order: 14
category: Hangar
---

```swift
try await repo.transaction { tx in
    try await tx.insert(order)
    try await tx.transaction { inner in
        try await inner.insert(lineItem)     // SAVEPOINT, not a new BEGIN
    }
}
```

`transaction { }` hands the closure a `Repo` bound to that transaction's own
connection. Calling it again on a `Repo` already inside one doesn't nest a
second `BEGIN` — Postgres doesn't support that — it opens a `SAVEPOINT`
instead, transparently. The body throwing rolls back exactly that
savepoint; the outer transaction is unaffected.

That is also the only way to recover from a failed statement. Postgres aborts
the whole transaction at the first failure, so a body that catches the error
and carries on can't commit anything — and rather than report success,
Hangar throws `HGR-QUERY-4101`, "The transaction was rolled back, not
committed", naming the statement that failed. Run a statement that may fail
inside a nested `transaction { }` and catch the error there: only the
savepoint rolls back.

## Isolation and retry

```swift
try await repo.transaction(
    isolation: .serializable, retryingOnSerializationFailure: 3
) { tx in
    guard let account = try await tx.one(Account.where { $0.id == id }) else {
        throw AccountNotFound()
    }
    try await tx.update(Changeset(original: account).change(\.balance, account.balance - amount))
}
```

`isolation:` applies only to the outermost `BEGIN` — a nested call's own
argument is ignored, since Postgres ties the level to the whole
transaction. `SERIALIZABLE` sometimes rejects a transaction outright when
two run concurrently against overlapping rows (SQLSTATE `40001`) or a
deadlock is detected (`40P01`); `retryingOnSerializationFailure` re-runs
the whole body on a fresh transaction when that happens, up to the given
attempt count.

Two things worth being deliberate about: the body must be safe to run more
than once (a side effect outside the database — a sent email — does not
roll back with the transaction, so keep those out of a retried body), and
only the *outermost* transaction retries — calling the retrying form on a
`Repo` already inside one doesn't retry anything, since a serialization
failure dooms the whole transaction and only whoever opened it can run it
again.

## `Multi`: steps as values

```swift
enum K {
    static let user = MultiKey<User>("user")
    static let profile = MultiKey<Profile>("profile")
}

var multi = Multi()
    .insert(K.user, userChangeset)
    .insert(K.profile) { results in profileChangeset(for: try results[K.user]) }

switch try await repo.run(multi) {
case .success(let values):
    let user = try values[K.user]
case .failure(let failure):
    logger.error("step \(failure.key) failed: \(failure.error)")
}
```

`repo.transaction { }` is enough right up until the steps need to be
conditional, at which point the closure body turns into nested `if`s around
database calls. `Multi` is built before anything runs — a step can be added
conditionally with an ordinary `if`, and a later step reads an earlier
one's result through a typed key (`results[K.user]` is a `User`, not a cast
dictionary lookup). A failed step is a value, not a thrown error:
`repo.run(multi)` returns `.failure` naming which step broke, what it
threw, and everything that had already completed before the rollback —
the throw path stays reserved for the transaction machinery itself. Every
step runs inside one transaction, on exactly the savepoint/isolation
machinery described above.

## Where to go next

- [Queries](/guides/hangar-queries) — bulk writes, for "the same values,
  every matching row" instead of a multi-step unit of work.
- [Changesets](/guides/hangar-changesets) — the validated writes `Multi`'s
  steps are usually built from.

[Part 2 of the tutorial](/tutorial/02-data/08-transactions) builds all of
this as runnable exercises.
