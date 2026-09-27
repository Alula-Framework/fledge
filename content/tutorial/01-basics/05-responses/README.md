---
title: Responses, status codes, and HTTPError
description: Shaping what a handler sends back, and how it fails on purpose.
order: 5
---

Returning a plain `String` or `Codable` value (§2) covers the common case,
but a handler that needs to choose its own status code or add a header
constructs a `Response` directly:

```swift
struct IssueSummary: Codable, ResponseEncodable {
    let number: Int
    let status: String
}

@PostRoute("/issues")
func create(_ context: RequestContext) throws -> Response {
    try Response.json(IssueSummary(number: 201, status: "open"), status: .created)
}

@DeleteRoute("/issues/:number")
func delete(_ context: RequestContext, number: Int) -> Response {
    .noContent
}
```

`curl -i` those two and you get `201 Created` with a JSON body, and
`204 No Content` with no body at all.

`Response.json` is the same JSON encoding a `Codable` return value gets
implicitly — this is that path, called by hand so you can pass `status:`.
`Response.text(_:status:)` and `Response.html(_:status:)` are the same idea
for the other two body shapes you'll reach for by hand. All three exist
because "the usual encoding, an unusual status code" shouldn't require
building headers and a body yourself.

## Failing on purpose

A handler doesn't need to catch its own errors to answer with the right
status code — it throws, and names the status when it does:

```swift
@GetRoute("/issues/:number")
func show(_ context: RequestContext, number: Int) throws -> Response {
    guard number > 0 else {
        throw HTTPError(.badRequest, "issue numbers start at 1")
    }
    guard number <= 200 else {
        throw HTTPError(.notFound, "no issue #\(number)")
    }
    return try Response.json(IssueSummary(number: number, status: "open"))
}
```

(Pretend there are 200 issues: `number <= 200` stands in for the
database lookup this tier has no database for — Part 3 replaces it with a
real query, and the error handling around it doesn't change.)

Both throws are the whole error path — nothing downstream needs a `catch`.
Every `HTTPError` (and anything else conforming to `HTTPErrorRepresentable`,
which is how `BodyDecodingError`'s 400 and the previous exercise's 415 reach
the wire) is caught centrally and rendered as
[RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) `application/problem+json`:

```bash
curl -i http://127.0.0.1:8080/issues/0
```
```
HTTP/1.1 400 Bad Request
Content-Type: application/problem+json

{"status":400,"title":"Bad Request","detail":"issue numbers start at 1"}
```

And `/issues/999` answers `404` with `"detail":"no issue #999"` — same
mechanism, different status, still no `catch` anywhere in the handler.
`/issues/abc` is a `400` too, but not one you wrote: the typed `number: Int`
parameter refused it before the handler ran, through this same rendering.

`title` is always the status's own reason phrase; `detail` is the message
you passed. Omit the message — `throw HTTPError(.forbidden)` — and `detail`
disappears from the body entirely rather than repeating `title` back at you.

## What never reaches the client

An error that doesn't conform to `HTTPErrorRepresentable` — a force-unwrap
you didn't mean to ship, a bug, anything unplanned — answers a bare `500`
with `detail` omitted:

```json
{"status":500,"title":"Internal Server Error"}
```

The actual error, in full, goes to `context.logger` — never to the response
body. This isn't a try/catch you write per handler; it's the same central
mapping that renders `HTTPError`, falling through to its `default` case.
The practical effect: a handler can let an unexpected error simply propagate
and trust that whatever it was, the client learns nothing more than "the
server failed" while you learn everything, in the logs.

Two kinds of error get a more useful answer than `500`, because they say
what they mean rather than what they are. `TemporarilyUnavailable` — a
dependency that can't serve right now — answers `503` with a `Retry-After`,
so a client knows to try again; Alula Data's errors for a database that is
unreachable, a pool with no free connection, or a deadlock are among them.
`RejectedInput` — the request asked for something wrong — answers `400` with a
message chosen for the client. Both are protocols in AlulaCore, so an error
type of your own can conform too.
