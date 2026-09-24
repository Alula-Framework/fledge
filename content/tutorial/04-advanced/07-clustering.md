---
title: PubSub and the clustering seams
description: What changes when you add Valkey — in prose and diagrams, not a live cluster.
order: 7
---

Every broadcast this part has written — a channel's, or an HTTP handler's
— goes through the same two-method seam underneath:

```swift
public protocol PubSub: Sendable {
    func publish(_ message: Message) async
    func subscribe(_ topic: String) -> AsyncStream<Message>
}
```

On one server, that's the whole story: `LocalPubSub` delivers in-process,
and every socket subscribed to a topic on this node sees every publish to
it. Nothing in `Channel`, `ChannelBroadcaster`, or a handler's own
`context.resolve(ChannelBroadcaster.self)` call knows or cares whether
that's true.

## The seam a second node plugs into

```swift
public protocol DistributedPubSubAdapter: Sendable {
    func broadcast(_ message: Message) async throws   // send to other nodes
    func incoming() -> AsyncStream<Message>             // receive from other nodes
}
```

Two methods, and nothing more. `ClusteredPubSub` is what wraps a local
core with one of these: on `publish`, it fans out locally *and*
broadcasts through the adapter; a background relay drains `incoming()`
back into local delivery. A publish on node A reaches every socket on A
immediately, and every socket on B once B's relay picks it up:

```
Node A                              Node B
┌─────────────────────┐             ┌─────────────────────┐
│ socket → publish     │             │                     │
│   │                  │             │                     │
│   ├─ LocalPubSub ──► sockets on A  │                     │
│   │                  │             │                     │
│   └─ adapter.broadcast ──────────► Valkey ──► adapter.incoming()
│                       │             │           │         │
│                       │             │           ▼         │
│                       │             │       LocalPubSub ─► sockets on B
└─────────────────────┘             └─────────────────────┘
```

Whichever server a client happened to connect to, a broadcast published
anywhere reaches every subscriber everywhere — including the sender's own
other sockets on a *different* node, which is exactly the case single-node
testing can never exercise.

## Turning it on is a module, not a rewrite

```swift
// Single node — the default:
modules: [AlulaPubSubModule.self, AppModule.self]

// Clustered — one module added, nothing else in the app changes:
modules: [AlulaPubSubValkeyModule.self, AppModule.self]
```

```yaml
pubsub:
  valkey:
    url: valkey://localhost:6379
```

`AlulaPubSubModule`'s factory composes *by presence*: it runs once, at
`freeze()`, checks whether some other module registered a
`DistributedPubSubAdapter`, and hands the application `ClusteredPubSub`
if one exists or the bare local core otherwise. Every earlier exercise's
`ChannelBroadcaster`/`Channel`/`Presence` code reads exactly the same
either way — the same architectural shape this tutorial's cache and data
source exercises already established, applied to the realtime stack.

Three things become clustered together the moment that one module is
added, because all three are built on this same seam: **Channels**
broadcasts reach sockets on other servers, **Presence** gets a transport
to sync membership over, and **`ClusteredPubSub`** itself becomes
reachable at all rather than a type with nothing to wrap. Two details
worth knowing before relying on it: a remote broadcast is bounded by a
timeout (five seconds by default) so a slow or unreachable adapter costs
one remote delivery, never the local publisher's own liveness; and every
broadcast carries an origin marker so a message a node publishes never
loops back to itself as if it arrived from somewhere else.
