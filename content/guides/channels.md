---
title: Channels
description: The envelope protocol, join as the authorization gate, and fan-out.
order: 1
category: Realtime
---

Every message, either direction, shares one shape:

```json
{"ref": "7", "topic": "room:42", "event": "new_msg", "payload": {}}
```

`ref` correlates a client's message with its reply; `ref: null` on
anything server-initiated. A `Channel` implements up to three methods
against that shape:

```swift
struct RoomChannel: Channel {
    let broadcaster: ChannelBroadcaster

    func join(_ topic: String, socket: Socket) async -> JoinResult {
        guard socket.principal != nil else { return .reject(.unauthenticated) }
        return .ok(initialState: ["room": .string(topic)])
    }

    func handle(_ event: InboundEvent, socket: Socket) async -> HandleResult {
        guard event.event == "new_msg", let body = event.payload["body"]?.stringValue else {
            return .error(reason: "unknown_event")
        }
        await broadcaster.broadcast(topic: event.topic, event: "new_msg", payload: event.payload,
                                     excluding: socket)
        return .reply(event.payload)
    }
}
```

## `join` is the authorization gate

There's no separate middleware step for "should this socket be allowed
into this topic" — `join` is that check, every time, per topic:
`.ok`, `.ok(initialState:)`, or `.reject(.unauthenticated)` /
`.reject(.forbidden)` / `.reject(JoinRejection("..."))`. A rejection
answers `alula:error` correlated to the join's own `ref`. Membership is
established *before* the reply is sent, which is what makes a broadcast
racing the join structurally unable to slip through the gap between
"admitted" and "actually receiving."

## `handle` answers three ways

`.reply(payload)` (answers `alula:reply`, echoing the inbound `ref`),
`.error(reason:)` (`alula:error`, same correlation), or `.none` — sends
nothing, so a `ref`-carrying message's own await on that ref times out on
the client's side. Whether an event replies is part of the channel's
contract with its client, not something the transport papers over with a
synthetic ack.

## `broadcast` reaches every subscriber; `push` reaches one

```swift
await broadcaster.broadcast(topic: event.topic, event: "new_msg", payload: event.payload)
await broadcaster.broadcast(topic: event.topic, event: "new_msg", payload: event.payload, excluding: socket)
socket.push(topic: event.topic, event: "ack", payload: .object([:]))   // just this connection
```

`ChannelBroadcaster` is an ordinary container singleton — anything holding
one can broadcast, not only a `Channel` implementation. An ordinary
`@PostRoute` handler resolves it exactly the same way to fan an HTTP
write out to socket subscribers:

```swift
let broadcaster = try context.resolve(ChannelBroadcaster.self)
await broadcaster.broadcast(topic: "project:\(project.key)", event: "issue_created", payload: wire(issue))
```

A real write-then-broadcast handler orders the two deliberately: persist
first, broadcast second. A message that reaches twenty subscribers and
then fails to insert has been read by everyone and exists for nowhere,
and no retry puts that back.

## Raw WebSockets, measured against this

Channels is built on `WebSocketUpgradeHandler`, not a parallel mechanism
to it — `@WebSocketRoute` plus a raw upgrade handler is still there for
the cases that don't need topics, presence, or a browser client. What
that costs to build by hand has actually been measured: a benchmark
project built the same realtime feature twice, once on Channels and once
hand-rolled against a lower-level framework. The hand-rolled version
needed roughly 300 lines of join/heartbeat/fan-out infrastructure that a
Channels app never writes — while the feature code itself, in both
versions, came out within single digits of line count. Channels doesn't
make application logic shorter; it removes the layer underneath it.

## Where to go next

- [Presence](/guides/presence) — who's currently in a topic, built on the
  same `Channel`/`Socket` primitives.
- [Testing](/guides/testing) — `ChannelWireClient` and
  `InMemoryChannelTransport`, for asserting on this protocol without a
  socket.

[Part 4 of the tutorial](/tutorial/04-advanced) builds all of this as
runnable exercises, including the measured comparison in full and a
capstone assembling it with everything else.
