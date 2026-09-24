---
title: WebSockets raw, then why Channels
description: What you would build by hand, before seeing what Channels replaces.
order: 1
---

A raw upgrade is one protocol, one method:

```swift
@Controller
struct EchoSocketController {
    @WebSocketRoute("/echo/:room")
    func echo(_ context: RequestContext) throws -> any WebSocketUpgradeHandler {
        EchoHandler(room: context.pathParam("room") ?? "?")
    }
}

struct EchoHandler: WebSocketUpgradeHandler {
    let room: String

    func handle(upgraded connection: WebSocketConnection, context: RequestContext) async throws {
        try await connection.send("welcome")
        for await frame in connection.frames {
            switch frame {
            case .text(let text):
                try await connection.send("echo: \(text)")
            case .close:
                return
            default:
                continue
            }
        }
    }
}
```

`@WebSocketRoute` generates a route exactly like `@GetRoute` does, just
tagged as an upgrade; the transport performs the HTTP 101 handshake and
hands your handler the frame stream. `WebSocketConnection` owns
fragmentation reassembly, masking, and the close handshake — you only ever
see whole `.text`/`.binary`/`.ping`/`.pong`/`.close` frames.

This is enough for an echo server. It is not enough for what a real
feature needs: named topics, an authorization check before a client joins
one, replying to one specific message versus broadcasting to everyone,
tracking who's currently connected, and doing all of that across more than
one server. Building those by hand, on top of exactly this API, is a real
project — and it's been measured, not guessed at.

## What building it by hand actually costs

A benchmark project built the same realtime issue board twice: once on
Alula's `Channel` protocol (the next exercise), once hand-rolled directly
on `WebSocketUpgradeHandler`, against Hummingbird. Both versions ship the
identical feature — join a project's board, post an issue, see it appear
live for everyone else watching. The measured line counts:

| | infrastructure | feature | total |
|---|---|---|---|
| Alula | 0 | 80 | 129 (incl. wiring) |
| hand-rolled | 315 | 73 | 449 |

"Infrastructure" is the envelope codec, the topic router, join/leave
lifecycle, ref/reply correlation, heartbeat and timeout handling, and the
fan-out subscriber registry — everything a real app needs *before* it can
write a single feature line. "Feature" is the board itself: authorizing a
join, handling an update, shaping the payload. The feature layers are
within seven lines of each other — 80 against 73 — which is the actual
claim this measurement supports: **Alula doesn't make application logic
shorter. It removes the layer underneath it.** The 315 hand-rolled lines
went into three files — a session handler, a wire-protocol codec, and a
topic/subscriber registry — each one a concurrency-sensitive piece of
infrastructure a hand-rolled app has to get right on its own, that a
Alula app never writes at all.

One honesty caveat worth keeping, since it's exactly the kind of thing
this tutorial tries not to skip: the hand-rolled version was written with
Alula's own implementation available as a design reference, which
materially favors its line count and its correctness — a team building
this cold, with no reference, should expect to spend more, not less.
