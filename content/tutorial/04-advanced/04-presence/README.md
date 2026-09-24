---
title: Presence
description: Track, state-then-diffs, the metas model, and the measured join-storm caveat.
order: 4
---

Tracking who's here is two calls, made from `join`:

```swift
func join(_ topic: String, socket: Socket) async -> JoinResult {
    guard let principal = socket.principal else { return .reject(.unauthenticated) }
    await presence.track(topic: topic, key: principal.subject,
                          payload: ["displayName": .string(principal.subject), "since": Self.timestamp()],
                          socket: socket)
    await presence.sendState(topic: topic, to: socket)
    return .ok(initialState: ["room": .string(topic)])
}
```

Untracking is automatic and structural — nothing below those two lines
exists to make cleanup happen. Whichever way this socket's membership of
`topic` ends, `track`'s bookkeeping is removed and a leave is broadcast to
everyone else, with no cleanup code of your own to write or forget.

## One identity, more than one meta

```swift
public struct PresenceEntry {
    let key: String              // a stable identity — Principal.subject, usually
    let metas: [PresenceMeta]     // one per live connection tracked under that key
}
```

A user with three browser tabs open is one person, present three times —
one key, three metas, each with its own `ref`. Closing one tab removes one
meta; only when the *last* one goes is the key genuinely gone, and only
then do other clients see a leave. `payload` is a flat `[String: String]`
your application controls entirely — Presence itself never reads it,
except for `"ref"`, a reserved key it manages and silently strips if you
try to set it yourself.

## State, then diffs — never the reverse

```
alula:presence_state   {"alice": {"metas": [{"ref": "w1", "status": "online"}]}}
alula:presence_diff    {"joins": {"bob": {...}}, "leaves": {}}
```

A newly joined socket gets the *whole* current list once, as
`alula:presence_state` — then every subsequent change arrives as a
`alula:presence_diff`, never the full list again. The ordering is
enforced, not just documented: `sendState` only fires once the join is
fully admitted (reply enqueued, subscription live), so a diff published in
the gap between "admitted" and "state sent" can never be missed — the
client always sees reply, then state, then diffs, with nothing able to
land out of order in between.

A client-side helper folds both message kinds into one running list with
two rules worth knowing before you write your own: within one diff,
leaves apply before joins, so a meta update — which travels as a leave of
the old meta and a join of the new one, same `ref` — becomes a clean
in-place replacement instead of a visible flicker; and joins upsert by
`ref`, so a diff that overlaps with the initial state (a real race, given
two independent pushes) is harmless rather than duplicated.

## The measured cost nobody's steady-state numbers caught

Fan-out latency for an already-stable room is unaffected by adding
presence. Connecting to one that's actively filling up is a different
story: 200 sockets joining a room in a burst went from roughly 150ms with
no presence at all to **616ms** with it — and a hand-rolled comparison
implementation measured **704–709ms** for the identical scenario, in the
same run. The mechanism is structural, not a bug in either: every join
broadcasts a presence diff to every socket *already* in the room, so
joining the Nth costs O(N) sends, and 200 joins in a burst costs O(N²)
total. This has nothing to do with clustering — it's the same cost on a
single node, because "everyone sees everyone else arrive" is inherently
quadratic in burst size regardless of how the diff gets delivered. It's
not a defect to route around; it's a real property worth knowing before
building a live "who's here" list for something that expects a burst of
simultaneous arrivals — a stream premiere, a scheduled event start —
rather than the gradual trickle most rooms actually see.
