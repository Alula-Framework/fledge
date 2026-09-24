---
title: Server-sent events
description: A one-way stream, for when a socket is more than the problem needs.
order: 4
---

```swift
@GetRoute("/events")
func events(_ context: RequestContext) -> Response {
    .serverSentEvents { events in
        await events.send(data: "hello", event: "greeting")
    }
}
```

An SSE endpoint is an ordinary `@GetRoute` handler — no upgrade, no separate
protocol handshake, just a response whose body stays open. `.serverSentEvents`
sets `Content-Type: text/event-stream` and `Cache-Control: no-cache` for you,
and hands the closure a writer rather than a raw byte stream:
`events.send(data:event:id:)` encodes one WHATWG-format event per call,
escaping the value so a stray newline in your data can't forge an extra field.
`send` is `async` — it awaits the socket's write backpressure — so every call
to it is `await`ed.

## Reacting to a client that leaves

`send` returns `false` once the client has disconnected — the natural way to
stop a loop that's producing from something else, like a subscription. The bus
is injected the same way any dependency is:

```swift
@Controller
struct ActivityController {
    // alula:hand-registered — the bus is provided by AlulaPubSubModule.
    @Inject var pubsub: any PubSub

    @GetRoute("/activity")
    func activity(_ context: RequestContext) -> Response {
        .serverSentEvents { events in
            for await message in pubsub.subscribe("activity") {
                let line = String(decoding: message.payload, as: UTF8.self)
                guard await events.send(data: line, event: "activity") else {
                    return   // client went away; the subscription tears down with us
                }
            }
        }
    }
}
```

Nothing here polls a cancellation flag — `guard await events.send(...) else {
return }` on the writer's own return value is the whole disconnect check, and it
composes naturally with a `for await` loop over any async sequence, not just a
timer you control yourself.

## What an SSE handler doesn't hold

This connects directly to the lesson from the first exercise of this part: a
database connection is leased only inside a `withRepo` bracket, and only for as
long as that bracket runs. An SSE handler that never opens a `withRepo` never
holds a connection out of the pool — so a stream can stay open for minutes
without tying up a connection the whole time. When it *does* need data, it
opens `withRepo` for exactly that query and hands the connection straight back,
even though the response itself keeps streaming. A long-lived endpoint doesn't
have to mean a long-held connection; that falls out of connections being
borrowed per operation rather than reserved for the whole request.

## Heartbeats

```swift
.serverSentEvents { events in
    while await events.sendHeartbeat() {
        try? await Task.sleep(for: .seconds(15))
    }
}
```

A heartbeat is a comment line (`: keep-alive`), invisible to `EventSource`'s
`message`/named-event listeners on the client, and its `Bool` return doubles as
the same disconnect check as a real event — a `while` loop over it stops itself
the moment nobody's listening anymore.

SSE covers the one-directional case, which is usually what a dashboard or an
activity feed actually needs; a client that must also send messages back over
the same connection is what [WebSockets and
Channels](/tutorial/04-advanced/01-websockets) are for, later in this tutorial.
