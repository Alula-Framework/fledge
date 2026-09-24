---
title: Testing channels
description: AlulaChannelsTesting, and asserting on a protocol instead of a socket.
order: 6
---

A join a channel should refuse is a protocol-level fact — the exact wire
message that comes back matters, not just that *something* was rejected:

```swift
@Test("join rejected: alula:error with the rejection reason and the ref")
func joinRejected() async throws {
    let harness = try Harness()
    let wire = try await harness.wire()
    try wire.send(ref: "9", topic: "room:locked", event: "alula:join")

    let error = try await wire.nextEnvelope()
    #expect(error == Envelope(
        ref: "9", topic: "room:locked", event: "alula:error",
        payload: ["reason": "forbidden"]))
}
```

`ChannelWireClient` is a deliberately dumb driver — it sends and reads raw
`Envelope` values over an in-memory socket, with no heartbeats, no
reconnect, no ref/reply correlation of its own. That's the entire point:
when what you're testing *is* the protocol — the exact close reason, the
exact shape of a rejection — a client that helpfully retries or hides
correlation from you would be testing the wrong layer. Underneath, it's
still `InMemoryWebSocket` — no socket, no port — the same primitive
`AlulaWebTesting` already gave you.

## Asserting on fan-out

```swift
@Test("one shout reaches every joined socket, including the sender")
func fanOut() async throws {
    let harness = try Harness()
    let alice = try await harness.wire("/socket?token=alice")
    let bob = try await harness.wire("/socket?token=bob")
    _ = try await alice.join("room:42")
    _ = try await bob.join("room:42")

    try alice.send(ref: "2", topic: "room:42", event: "shout", payload: ["body": "hello"])

    let toBob = try await bob.expectEnvelope { $0.event == "shouted" }
    #expect(toBob?.payload == ["body": "hello"])
    #expect(toBob?.ref == nil)   // server-initiated push, never correlated to a client ref
}
```

The same shape proves the negative cases that matter just as much:
`excluding:` broadcasts skip only the sender, and a shout in one room
never reaches a socket joined to a different one. All of this runs without
opening a socket — routing, join gates, and PubSub fan-out are exercised
for real, just never over a wire.

## When the client's own behavior is what you're testing

For application-level tests — does my UI code handle a join correctly,
not just does the server answer correctly — `InMemoryChannelTransport`
drives a real `ChannelClient`, reconnection and all, against a real server
with zero sockets:

```swift
// harness.testClient is a TestClient built over the socket route the way the
// app composes it — AlulaChannelsModule's `sockets` behind SocketController.
// RealtimeTests.swift in the demo template shows that wiring in full.
let harness = try Harness()
let transport = InMemoryChannelTransport(testClient: harness.testClient)
let client = ChannelClient(url: URL(string: "alula-test:///socket")!, transport: transport)

await #expect(throws: ChannelClientError.channelError(reason: "forbidden")) {
    try await client.channel("room:locked").join()
}
```

The two tools sit at different layers on purpose: `ChannelWireClient` when
the assertion is about frames on the wire, `InMemoryChannelTransport` when
it's about how a real client built on `ChannelClient` behaves — both
without a socket, for the same reason `TestClient` never opened one either.
