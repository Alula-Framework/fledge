---
title: "Requests & Responses"
description: Content negotiation, status codes, and shaping errors on purpose.
order: 2
category: Alula
---

Returning a plain `String` or `Codable` value covers the common case; a
handler that needs its own status code or headers constructs a `Response`
directly:

```swift
@PostRoute("/posts")
func create(_ context: RequestContext, body: CreatePost) throws -> Response {
    try Response.json(["id": newID.uuidString], status: .created)
}

@DeleteRoute("/posts/:id")
func delete(_ context: RequestContext) -> Response {
    .noContent
}
```

`Response.json`/`.text`/`.html` are the same encoding a return value gets
implicitly, called by hand so you can pass `status:`.

## Request bodies negotiate their format

A handler that takes a body names it as a typed parameter — no manual
decoder, no `context.request.body`:

```swift
struct CreatePost: Decodable { let title: String; let body: String }

@PostRoute("/posts")
func create(_ context: RequestContext, body: CreatePost) throws -> Response {
    try Response.json(["title": body.title], status: .created)
}
```

The same handler accepts either `application/json` or
`application/x-www-form-urlencoded` unchanged — `CreatePost` is just
`Decodable`, nothing about it says which wire format it came from, so an
ordinary HTML `<form>` and a JavaScript client posting JSON both reach the
same code. A `Content-Type` that's neither answers `415 Unsupported Media
Type` before decoding is even attempted; one that matches but doesn't fit
the type answers `400`, naming what was wrong.

## Failing on purpose

A handler doesn't catch its own errors to answer with the right status —
it throws, and names the status when it does:

```swift
guard let post = try await repo.one(Post.where { $0.id == id }) else {
    throw HTTPError(.notFound, "no such post")
}
```

Every `HTTPError` — and anything else conforming to `HTTPErrorRepresentable`
— is caught centrally and rendered as
[RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) `application/problem+json`:

```json
{"status": 404, "title": "Not Found", "detail": "no such post"}
```

`title` is always the status's own reason phrase; `detail` is the message
you passed, omitted entirely (not repeated) when you don't pass one. An
error that *doesn't* conform to `HTTPErrorRepresentable` — a force-unwrap
you didn't mean to ship, a database timeout — answers a bare `500` with no
`detail` at all; the real error goes to the log, never to the client. A
handler can let an unexpected error simply propagate and trust that the
client learns nothing more than "the server failed," while the log has
everything.

## Where to go next

- [Routing and Controllers](/guides/routing-and-controllers) — `@Controller`
  and `@GetRoute`, and the parameters a handler can pull from a request.
- [Configuration](/guides/configuration) — the layered config a running
  app reads its own settings from.

[Part 1 of the tutorial](/tutorial/01-basics) walks through all of this as
runnable exercises, `curl` output included.
