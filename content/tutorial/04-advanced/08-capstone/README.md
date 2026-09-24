---
title: "Capstone: the live issue board"
description: Assembled from everything — identical to the benchmark app, conformance-tested from outside.
order: 8
---

Every earlier exercise touched one seam at a time. A real app needs them
touching each other: a join that only admits someone with real access to a
project, a socket write and an HTTP write landing on the exact same
subscribers, presence showing who's actually looking at the board right
now. This capstone is that app — a live issue tracker, one project per
board, built from nothing this tutorial hasn't already covered.

```swift
// `AlulaChannels.Channel`, qualified — see the note below the code
struct BoardChannel: AlulaChannels.Channel {
    let repo: Repo
    let broadcaster: ChannelBroadcaster
    let presence: any Presence

    func join(_ topic: String, socket: Socket) async -> JoinResult {
        guard let principal = socket.principal else { return .reject(.unauthenticated) }
        guard let key = Self.projectKey(from: topic),
              let project = try? await repo.one(Project.where { $0.key == key })
        else { return .reject(JoinRejection("no_such_project")) }

        await presence.track(topic: topic, key: principal.subject,
                              payload: ["displayName": principal.subject], socket: socket)
        await presence.sendState(topic: topic, to: socket)
        return .ok(initialState: ["key": .string(project.key), "name": .string(project.name)])
    }

    func handle(_ event: InboundEvent, socket: Socket) async -> HandleResult {
        guard event.event == "update_issue", let id = event.payload["id"]?.stringValue,
              let issueID = UUID(uuidString: id), let status = event.payload["status"]?.stringValue,
              let issue = try? await repo.one(Issue.where { $0.id == issueID })
        else { return .error(reason: "invalid_event") }

        // update, persist, then broadcast — the same ordering every
        // write-then-broadcast handler in this tutorial has used
        guard let updated = try? await repo.update(Changeset(original: issue).change(\.status, status))
        else { return .error(reason: "handler_error") }
        await broadcaster.broadcast(topic: event.topic, event: "issue_updated", payload: Self.wire(updated))
        return .reply(["ok": true])
    }
}
```

The HTTP side reaches the same topic through the same `ChannelBroadcaster`
this part's third exercise covered — a `POST /projects/:key/issues` and a
socket's own `update_issue` both end up broadcasting `issue_created` /
`issue_updated` to `project:<key>`, so a board sees a change exactly the
same way whichever door it came through. `join`'s authorization check, the
two-call presence integration, and the persist-then-broadcast ordering are
all exercises 1 through 5 of this part, applied together rather than in
isolation.


Two things in that first line are worth pausing on, because the capstone is
the first exercise where they can bite at all — both come from combining
realtime with data in one file.

`Channel` has to be written `AlulaChannels.Channel`. `AlulaDataPostgres`
transitively re-exports NIO, and `NIOCore` has a `Channel` of its own (a
socket, not a topic), so a file importing both sees two and refuses to
guess: *'Channel' is ambiguous for type lookup in this context*. Qualifying
the one you mean is the whole fix. No earlier exercise hits this, because
none of them import both halves.

And the presence payload is `[String: String]` — plain values, not
`JSONValue`. `principal.subject` goes in as-is; wrapping it in `.string(…)`
is a type error rather than a nicety.

## Proving it from outside, not from inside

Every test this tutorial has shown so far — `TestClient`,
`ChannelWireClient`, `InMemoryChannelTransport` — runs *inside* the
process, against Alula's own test doubles. A capstone this size deserves
a different kind of proof: a plain client, in a different language,
speaking only the wire protocol, against a real running server over a
real socket. Something like:

```javascript
const ws = new WebSocket(`ws://localhost:8090/socket?token=${token}`);
ws.send(JSON.stringify({ref: "1", topic: "project:BENCH", event: "alula:join", payload: {}}));
// assert: alula:reply with {key, name}, then alula:presence_state,
// before anything else arrives
```

That's "conformance-tested from outside": nothing about the check cares
that the server happens to be written in Swift, or that it's Alula
underneath rather than something hand-rolled — it asserts on the protocol
itself, the same envelope shape and reserved events this whole part has
been teaching, from a client with no special access to the server's
internals. A real POST to create an issue, checked against a socket
connected before the request was made, is the single most convincing test
this app can have: it proves the HTTP and WebSocket paths actually agree,
which is the whole point of routing both through one broadcaster.

## What building this twice actually showed

The first exercise of this part cited a measurement built exactly this
way: the same board, built once on Alula, once by hand against a lower-
level framework, both checked by the identical outside harness. The
verdict from that comparison is worth restating now that you've built
the Alula side yourself: the feature code — everything in `BoardChannel`
above — came out within single digits of line-count either way. The gap
was entirely in the roughly 300 lines of join/heartbeat/fan-out
infrastructure a hand-rolled version has to write, get concurrency-safe,
and maintain, that an Alula app never writes at all. Building this
capstone is, in a real sense, building only the half of that comparison
that was ever actually about your application.
