---
title: Heartbeats and the four teardown paths
description: Clean close, abrupt drop, explicit leave, and the heartbeat reaper.
order: 5
---

The previous exercise's `presence.track` cleans up "automatically,
structurally, on any teardown path" — this exercise is what that phrase
actually covers. A socket's membership can end four distinct ways, and
Presence (and everything else registered against it) reacts to all four
the same way, through one seam:

```swift
socket.onTopicTerminated(topic) {
    // runs exactly once, however this membership actually ended
}
```

Presence never touches a close code or a socket's lifecycle directly — it
registers one of these callbacks per `track()` call, and every teardown
path funnels through the same handful of call sites that fire it. That's
the whole trick: cleanup isn't four code paths remembering to call the
same cleanup function, it's one callback wired once.

## The four paths

**Clean close** — the client sends a real WebSocket close frame. The
frame loop reading `connection.frames` sees `.close` and returns.

**Abrupt drop** — the connection simply vanishes: no close frame, TCP
reset, a phone losing signal. From the frame loop's point of view this is
indistinguishable from clean close — the `for await` loop over
`connection.frames` just ends either way. The two only diverge in how
*fast* the server notices: a local process dying still tends to send a
FIN the transport sees quickly; a genuinely half-open connection (nothing
at the network layer ever fires) is caught by nothing here at all — which
is exactly why the fourth path exists.

**Explicit leave** — `alula:leave` on one topic, socket otherwise
unaffected:

```json
{"ref": "1", "topic": "room:1", "event": "alula:leave", "payload": {}}
```

Only that topic's membership ends; other topics the same socket joined
stay live. This is the one path that's a normal *message* rather than
something happening to the connection itself.

**Heartbeat reaper** — a per-connection watchdog checks, on an interval,
whether anything has arrived recently:

```swift
while !Task.isCancelled {
    try await Task.sleep(for: configuration.heartbeatCheckInterval)   // 15s default
    if await session.idleDuration > configuration.heartbeatTimeout {   // 60s default
        await session.teardown()
        try? await connection.close(code: WebSocketCloseCode(ChannelCloseCode.heartbeatTimeout),
                                     reason: "heartbeat timeout")
        return
    }
}
```

*Any* inbound frame counts as liveness, not only an explicit
`alula:heartbeat` — a socket that's actively sending real messages never
needs to heartbeat at all to stay alive. Worst-case detection latency is
the timeout plus one check interval, so a socket can go unnoticed for up
to 75 seconds under the defaults before this path closes it.

## A fifth name worth knowing: `alula:close`

The wire protocol also has `alula:close` — a message, sent while the
socket is still open, that means "end this whole connection gracefully,"
distinct from both a bare peer-sent close frame and from `alula:leave`'s
single-topic scope. It exists because a server can't always rely on the
transport noticing a connection is done: a half-open socket never
acknowledges an ordinary close handshake, which is the same category of
problem the heartbeat reaper exists to catch from the other direction.
Whichever of these five names it goes by, every one funnels into the same
idempotent teardown, and every `onTopicTerminated` callback — Presence's
included — fires exactly once no matter which.
