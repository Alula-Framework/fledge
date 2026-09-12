---
title: Wiring Hangar into Flight
description: Leasing a connection per operation with withRepo, and the connection-affinity bug this guide exists to prevent.
order: 1
---

Every exercise so far constructed a `Repo` by hand. Inside a real Flight app, a
controller injects the connection *pool* and leases a repo from it for each
operation:

```swift
@Controller
struct IssueController {
    // flight:hand-registered — PostgresDataModule provides the pool.
    @Inject var pool: PostgresDataSource

    @GetRoute("/issues/:id")
    func show(_ context: RequestContext) async throws -> Issue {
        guard let idText = context.pathParam("id"), let id = UUID(uuidString: idText) else {
            throw HTTPError(.badRequest, "malformed id")
        }
        return try await pool.withRepo { repo in
            guard let issue = try await repo.one(Issue.where { $0.id == id }) else {
                throw HTTPError(.notFound, "no such issue")
            }
            return issue
        }
    }
}
```

This is the same `Issue` you queried directly in Part 2 — the entity and the
predicate haven't changed at all, only where the `Repo` comes from. Inside the
`withRepo` closure it's exactly the `repo` you already know.

## Why the pool, and not a `Repo`, is what you hold

A `Repo` is bound to a single database connection. A controller is built once
and lives for the whole process, so if it *held* a `Repo`, it would pin one
connection for the life of the app — every request funnelling through the same
connection, or worse, a connection captured by something that outlives the
request that leased it. That's the connection-affinity bug this exercise exists
to prevent, and Flight prevents it by not offering a long-lived `Repo` at all.

Instead the controller holds the `PostgresDataSource` — the pool — and
`withRepo` leases a connection, hands you a `Repo` bound to it, and returns the
connection to the pool when the closure ends. The borrow is exactly as wide as
the closure: it starts where you can see it and ends when the closure returns.

`PostgresDataModule<PrimaryDataSource>` provides the pool; the
`// flight:hand-registered` marker acknowledges that `PostgresDataSource` comes
from that module rather than being scanned as a component in this target.

## One lease is one connection — so group what must stay together

The rule that falls out of this: everything that must run on the *same*
connection — and therefore in the same transaction — goes inside a *single*
`withRepo`. Two separate `withRepo` calls are two independent leases, and
nothing guarantees they land on the same connection:

```swift
// One connection for both statements: correct.
try await pool.withRepo { repo in
    let issue = try await repo.insert(newIssue)
    try await repo.insert(AuditEntry(issueID: issue.id, action: "created"))
}

// Two leases: the audit row could be written on a different connection, so
// these are NOT one atomic unit even though they look adjacent.
try await pool.withRepo { repo in try await repo.insert(newIssue) }
try await pool.withRepo { repo in try await repo.insert(auditEntry) }
```

When those statements must also be atomic, open a transaction on that one
shared connection with Hangar's own `repo.transaction { }`:

```swift
try await pool.withRepo { repo in
    try await repo.transaction { tx in
        let issue = try await tx.insert(newIssue)
        try await tx.insert(AuditEntry(issueID: issue.id, action: "created"))
    }
}
```

`repo.transaction` is the *only* transaction mechanism — there is no
`@Transactional` annotation. Hangar owns transactions because only it can
offer isolation levels, savepoint nesting (a `transaction` inside a
`transaction` becomes a savepoint, by design), and automatic retry on a
serialization failure — none of which a method annotation could express.
