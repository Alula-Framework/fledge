---
title: Testing
description: Four tiers — direct unit tests, query shape without a database, a rolled-back database tier, and a small end-to-end one.
order: 4
category: Flight
---

Flight testing has four tiers, and the useful question is always *which one does
this belong in*:

| Tier | Needs | Proves | How many |
|---|---|---|---|
| **Unit** — the type with fakes | nothing | your logic | most of them |
| **Query shape** — `debugSQL` | nothing | the SQL you *built* | many, cheap |
| **Database** — a rolled-back transaction | Postgres | the SQL you built is *right* | few, targeted |
| **End-to-end** — `TestClient` | nothing (or Postgres) | the wiring | a handful |

The first two need no infrastructure at all, and between them they cover most of
what people reach for a database to check. That is the point of the split: a
database is needed for a smaller set of questions than it first appears.

A controller is a struct and a route is one of its methods; a service is a
struct that takes its collaborators. So most Flight tests are ordinary Swift —
construct the type with a fake, call the method, assert on what comes back. No
container, no router, no HTTP.

```swift
// A service: fake repository in, called directly.
let service = UserService(repository: MockUserRepository(users: [ada]))
#expect(try await service.find(byID: ada.id) == ada)

// A controller: a real service over a fake repo; the route method is a function.
let controller = UserController(
    users: UserService(repository: MockUserRepository(users: [ada])))
let user = try await controller.getUser(.mock(pathParameters: ["id": ada.id.uuidString]))
#expect(user.id == ada.id)
```

`MockUserRepository` is a plain type conforming to `UserRepositoryProtocol`, and
`RequestContext.mock(...)` builds a context with no transport behind it. Nothing
is registered or resolved — wiring the real dependency in is the composition
root's job, which a unit test replaces by hand. Handlers return domain values
(`getUser` returns a `User`), so a unit test asserts on the value or, for the
not-found path, that it throws:

```swift
await #expect(throws: HTTPError.self) {
    try await controller.getUser(.mock(pathParameters: ["id": UUID().uuidString]))
}
```

Mock at whichever seam the test is about: a fake repository under a real
service, or a controller that injects a protocol (`@Inject var users: any
UserServicing`) so a `MockUserService` can stand in directly.

## End-to-end, sparingly

Unit tests deliberately skip the wiring — that a path routes, a body decodes, a
return value encodes, the declared middleware runs, an error becomes the right
status. A *small* number of whole-path tests cover that with `TestClient`,
which dispatches through the same `Request`/`Response` values a real socket
would produce — skipping the network but running routing, middleware, DI, and
encoding for real:

```swift
let client = try TestClient(routes: [
    UserController._flightRoute_getUser_1 { _ in
        UserController(users: UserService(repository: MockUserRepository(users: [ada])))
    }
])
#expect(await client.get("/user/\(ada.id)").status == .ok)
```

Keep this tier small — a handful of representative paths, not one per handler.
The unit tests above are where logic is exercised; these prove the plumbing
once.

## Query shape, without a database

A query in Hangar is a *value*: nothing runs until a `Repo` executes it. So the
question "did I build the query I meant?" can be answered with no database at
all, by looking at the SQL it renders to:

```swift
let sql = Post.where { $0.title == "secret" }.debugSQL
#expect(sql.contains("$1"))       // the value is bound…
#expect(!sql.contains("secret"))  // …never interpolated
```

This is the tier people most often skip, and it is the cheapest one they have.
"Does my dynamic filter build the `WHERE` clause I expect", "does this soft-delete
scope actually add `deleted_at IS NULL`", "does the preload emit one `= ANY($1)`
rather than N queries" — every one of those is a question about *construction*,
answerable in microseconds with no server running.

What it cannot tell you is whether that SQL returns the right rows. For that you
need a real database — but far less often than you would guess.

## Queries against a real database, rolled back

When the assertion really is about data — a three-table join, a preload, a
constraint, what a migration produced — use a real Postgres. Substituting a
different engine would test a different engine: Flight's SQL uses `DISTINCT ON`,
arrays and JSONB operators, which SQLite cannot even parse, so a green test
against a stand-in proves nothing about what ships.

The trick is to make a real database cheap. Run each test inside a transaction
and roll it back:

```swift
try await withSandbox(pool) { repo in
    let ada = try await repo.insert(Author(id: UUID(), name: "ada"))
    let posts = try await repo.all(
        Post.where { $0.authorID == ada.id }.preload(\.comments))
    #expect(try posts[0].comments.get().count == 3)
}   // nothing was committed; there is nothing to clean up
```

`withSandbox` ships in Hangar's `HangarTesting` product. It is the same idea as
Ecto's `Ecto.Adapters.SQL.Sandbox`: isolation comes from nothing ever being
committed, rather than from emptying tables between tests. Two things follow —
there is no cleanup step, and because no test is mutating shared state, these
tests can run **in parallel**.

Two rules make it work:

- **Scope your assertions.** A sandbox empties nothing, so a query still sees
  every *committed* row. `repo.count(User.all) == 3` is only true of an
  otherwise-empty table; scope to the rows the test created
  (`User.where { $0.id.in(ids) }`) and the test stops depending on what else has
  run. That independence is what makes parallelism safe.
- **Know what a sandbox cannot test.** Anything needing a second connection
  (replica routing, `LISTEN`/`NOTIFY`, advisory locks) cannot see uncommitted
  rows. Neither can a test whose subject *is* commit durability — that one is
  the dangerous case, because it keeps passing while measuring something else.

One thing that is *not* the answer: `FlightDataTesting`'s `InMemoryDataSource`
is a connection pool, not a database — it never executes SQL. It is for testing
pool behaviour, not queries.

## Testing channels without a socket

```swift
@Test("join rejected: flight:error with the rejection reason and the ref")
func joinRejected() async throws {
    let harness = try Harness()
    let wire = try await harness.wire()
    try wire.send(ref: "9", topic: "room:locked", event: "flight:join")

    let error = try await wire.nextEnvelope()
    #expect(error == Envelope(ref: "9", topic: "room:locked", event: "flight:error",
                               payload: ["reason": "forbidden"]))
}
```

`ChannelWireClient` is a deliberately dumb protocol driver — raw `Envelope`s
over an in-memory socket, no heartbeats, no reconnect, no correlation of its
own — for asserting on the wire itself. When the assertion is instead about how
a real client built on `ChannelClient` behaves, `InMemoryChannelTransport`
drives one against a real server with the same zero sockets, reconnection
included. Both sit on the identical `InMemoryWebSocket` primitive
`TestClient.webSocket(_:)` already uses — Channels testing is built on Web's,
not a separate mechanism.

## Where to go next

- [Channels](/guides/channels) — the protocol `ChannelWireClient` asserts on.
- [Routing and Controllers](/guides/routing-and-controllers) — what `TestClient`
  actually dispatches through.

[Part 3](/tutorial/03-intermediate/07-testing) and
[Part 4](/tutorial/04-advanced/06-testing-channels) of the tutorial build both
halves of this as runnable exercises.
