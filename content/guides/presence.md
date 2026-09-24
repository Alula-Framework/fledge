---
title: Presence
description: Track, state-then-diffs, and the measured cost of a join storm.
order: 2
category: Realtime
---

Tracking who's here is two calls, made from a channel's `join`:

```swift
await presence.track(topic: topic, key: principal.subject,
                      payload: ["displayName": principal.name], socket: socket)
await presence.sendState(topic: topic, to: socket)
```

Untracking is automatic and structural — nothing beyond those two lines
exists to make cleanup happen. Whichever way this socket's membership of
`topic` ends, `track`'s bookkeeping is removed and a leave broadcast to
everyone else, with no cleanup code of your own to write or forget.

## One identity, more than one meta

```swift
struct PresenceEntry { let key: String; let metas: [PresenceMeta] }
```

A user with three browser tabs open is one person, present three times —
one key, three metas, each with its own `ref`. Closing one tab removes
one meta; only when the last one goes do other clients see a leave.
`payload` is a flat `[String: String]` your application controls
entirely.

## State, then diffs — never the reverse

```
alula:presence_state   {"alice": {"metas": [{"ref": "w1", "status": "online"}]}}
alula:presence_diff    {"joins": {"bob": {...}}, "leaves": {}}
```

A newly joined socket gets the whole current list once, as
`alula:presence_state`; every later change arrives as a
`alula:presence_diff`, never the full list again. The ordering is
enforced: `sendState` only fires once the join is fully admitted, so a
diff published in the gap between "admitted" and "state sent" can never
be missed. A client-side sync helper folds both into one list, applying
leaves before joins within a diff (so a meta update — which travels as a
leave-then-join for the same `ref` — becomes a clean in-place replacement)
and upserting joins by `ref` (so overlap between the initial state and a
concurrent diff is harmless).

## The measured cost nobody's steady-state numbers catch

Fan-out latency for an already-stable room is unaffected by adding
presence. Connecting to one that's actively filling up is a different
story: 200 sockets joining a room in a burst measured roughly 4-5×
slower with presence than without. The mechanism is structural, not a
bug: every join broadcasts a diff to every socket *already* in the room,
so joining the Nth costs O(N) sends, and joining 200 at once costs O(N²)
total. This has nothing to do with clustering — it reproduces identically
on a single node, and a hand-rolled comparison implementation paid the
same shape of cost, not a smaller one, for the identical scenario. It's
not a defect to route around; it's a real property worth knowing before
building a live "who's here" list for something that expects a burst of
simultaneous arrivals rather than the gradual trickle most rooms actually
see.

## Where to go next

- [Channels](/guides/channels) — `join`/`handle`/`broadcast`, the
  protocol Presence's messages ride on top of.
- [Testing](/guides/testing) — asserting on presence state/diff messages
  without a socket.

[Part 4 of the tutorial](/tutorial/04-advanced/04-presence) builds this
as two runnable exercises, including the teardown paths that make
cleanup "automatic" a real, verified guarantee rather than a hope.
