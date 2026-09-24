---
title: The envelope protocol
description: Join as the authorization gate; handle, reply, and broadcast.
order: 2
---

Every message either direction, client to server or server to client,
shares one shape:

```json
{"ref": "7", "topic": "room:42", "event": "new_msg", "payload": {}}
```

`ref` correlates a client's message with its reply; `ref: null` on
anything server-initiated. All four keys are always present — one
well-designed shape, no optional-field dialects to branch on. A `Channel`
implements three methods against that shape, only one of them required in
practice:

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

## `join` is the authorization gate, literally

There's no separate middleware step for "should this socket be allowed
into this topic" — `join` *is* that check, every time, per topic:

```swift
.ok                                    // admit, nothing to send back
.ok(initialState: someValue)           // admit, plus one value the client gets immediately
.reject(.unauthenticated)              // .forbidden also built in; JoinRejection(_:) for anything else
```

A rejection answers `alula:error` on the wire, correlated to the join's
own `ref` if the client sent one — the client's `join()` call throws,
never silently hangs. Membership is established *before* the reply is
sent, which matters more than it looks: it's what makes a broadcast that
races the join structurally unable to slip through the gap between
"admitted" and "actually receiving."

## `handle` answers three ways

`InboundEvent` carries `topic`, `event`, `payload`, and the inbound `ref`
(present when the client wants a reply). `HandleResult` is one of:

- **`.reply(payload)`** — answers `alula:reply`, echoing the inbound
  `ref`, straight back to the sender.
- **`.error(reason:)`** — answers `alula:error`, same correlation.
- **`.none`** — sends nothing. On a `ref`-carrying message this means the
  client's own await on that ref times out on its side; whether an event
  replies at all is part of the channel's contract with its client, not
  something the transport should paper over with a synthetic ack.

## `broadcast` reaches every subscriber; `push` reaches one

```swift
await broadcaster.broadcast(topic: event.topic, event: "new_msg", payload: event.payload)
await broadcaster.broadcast(topic: event.topic, event: "new_msg", payload: event.payload,
                             excluding: socket)   // "everyone but the sender"
socket.push(topic: event.topic, event: "ack", payload: .object([:]))   // just this one connection
```

`excluding:` is the shape a chat message wants when the sender already
rendered its own message optimistically and doesn't need an echo. A real
write-then-broadcast handler orders the two deliberately:

```swift
let stored = try await chat.post(message)
await broadcaster.broadcast(topic: event.topic, event: "new_msg",
                             payload: wire(stored), excluding: socket)
return .reply(wire(stored))
```

Persist first, broadcast second — a message that reaches twenty
subscribers and then fails to insert has been read by everyone and exists
for nowhere, and no retry puts that back. The sender gets the canonical,
persisted row through its own `.reply`; broadcasting to everyone else
after the write already succeeded is what `excluding:` is for.

## Topics can be patterns

`registerChannel("room:*")` matches any topic starting with `room:`, so one
`Channel` type serves every room — `event.topic`/the `topic` parameter
tells you which one a given join or message was actually for. Reserved,
framework-owned events all share a `alula:` prefix (`alula:join`,
`alula:reply`, `alula:error`, `alula:heartbeat`, among others) and
`"alula"` itself can never be joined as an ordinary topic — broadcasting
under a `alula:`-prefixed event name from your own code is refused
rather than colliding with the protocol's own control channel.
