---
title: Testing
description: Direct unit tests, a small end-to-end tier, and testing channels without a socket.
order: 4
category: Flight
---

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

## What doesn't fit: Hangar directly

`FlightDataTesting` ships an `InMemoryDataSource` for the generic `DataSource`
seam, but it never executes SQL — it's a connection pool, not a database.
Hangar's `Repo` is built directly on `PostgresConnection`, not on `DataSource`,
so there's no seam to swap it into underneath a `Repo`-based controller. The
answer is the same principle the unit tests above use: depend on a protocol of
your own, and pass a fake conforming to it. A test that genuinely needs to prove
a query renders and runs correctly needs real Postgres — Hangar's own suite uses
a throwaway server for exactly that, and an application should reach for the same
tier rather than a faster substitute pretending to be one.

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
