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
implements `join` and `handle` against that shape, and optionally `leave`:

```swift
struct RoomChannel: Channel {
    let broadcaster: ChannelBroadcaster

    func join(_ topic: String, socket: Socket) async -> JoinResult {
        guard socket.principal != nil else { return .reject(.unauthenticated) }
        return .ok(initialState: ["room": .string(topic)])
    }

    func handle(_ event: InboundEvent, socket: Socket) async -> HandleResult {
        guard event.event == "new_msg", event.payload["body"]?.stringValue != nil else {
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
never silently hangs.

A join frame carries a payload like any other message, and a join that needs
it — a cursor ("I have everything up to 812"), a filter, a client version —
adopts `PayloadJoinChannel` instead and implements the one `join` that
receives it:

```swift
struct TimelineChannel: PayloadJoinChannel {
    func join(_ topic: String, payload: JSONValue, socket: Socket) async -> JoinResult {
        let after = payload["after"]?.intValue ?? 0
        return .ok(initialState: ["events": await timeline(topic, after: after)])
    }
    func handle(_ event: InboundEvent, socket: Socket) async -> HandleResult { .none }
}
```

That saves the second message and the round trip a catch-up would otherwise
take. On the Swift client, `join(payload:)` sends a fixed payload, and
`join(payloadForEachJoin:)` computes one for every join *and* every automatic
rejoin — so a reconnecting client says what it holds now, not what it held
when it first joined. Membership is established *before* the reply is
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

A module declares its channels as values, and a pattern can be a prefix:

```swift
struct AppModule: AlulaModule {
    static var dependencies: [any AlulaModule.Type] { [AlulaChannelsModule.self] }

    let channels: [ChannelRegistration] = [
        ChannelRegistration("room:*") { channel in
            RoomChannel(broadcaster: channel.broadcaster)
        }
    ]
}
```

`"room:*"` matches any topic starting with `room:`, so one `Channel` type
serves every room — `event.topic`/the `topic` parameter tells you which one a
given join or message was actually for. Patterns are exact (`"lobby"`),
prefix (`"room:*"`) or catch-all (`"*"`); the most specific wins, and a
duplicate or malformed pattern fails startup, not a join. Each join builds one
`Channel` instance per socket and topic, so an instance may keep state for
that membership. Reserved,
framework-owned events all share an `alula:` prefix (`alula:join`,
`alula:reply`, `alula:error`, `alula:heartbeat`, among others) and
`"alula"` itself can never be joined as an ordinary topic — broadcasting
under an `alula:`-prefixed event name from your own code is refused
rather than colliding with the protocol's own control channel.
