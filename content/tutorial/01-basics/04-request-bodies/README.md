---
title: Request bodies and content negotiation
description: JSON and forms, both handled, with no decoder you have to write.
order: 4
---

A handler that takes a body names it as a second parameter:

```swift
struct NewIssue: Decodable {
    let title: String
    let priority: String
}

@PostRoute("/issues")
func create(_ context: RequestContext, body: NewIssue) throws -> Response {
    // body.title, body.priority — already decoded, already typed
    try Response.json(["title": body.title, "priority": body.priority], status: .created)
}
```

That's the whole shape: `body: NewIssue` in the method signature, no
`context.request.body`, no manual `JSONDecoder`. The macro generates the
decode call for you, and it decodes based on the request's actual
`Content-Type` — which means the same handler accepts either of these,
unchanged:

```bash
curl -X POST http://127.0.0.1:8080/issues \
  -H "Content-Type: application/json" \
  -d '{"title": "Login broken", "priority": "high"}'

curl -X POST http://127.0.0.1:8080/issues \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "title=Login+broken&priority=high"
```

Both answer `{"priority":"high","title":"Login broken"}` — JSON and
form-urlencoded decode into the same `NewIssue`, because `NewIssue` is
just `Decodable` — nothing about it says which wire format
it came from. This matters more than it looks: a plain HTML `<form
method="post">` submits as `application/x-www-form-urlencoded`, so the
exact same handler serves a JavaScript client posting JSON and an
ordinary HTML form with zero JavaScript at all. You don't write a
form-specific handler and a JSON-specific handler for the same resource.

## What happens when negotiation fails

A `Content-Type` that's neither JSON nor form-urlencoded answers `415
Unsupported Media Type` — not a decoding error, a rejection before
decoding is even attempted. A `Content-Type` that *is* one of the two, but
whose body doesn't match your `Decodable` type, answers `400` naming what
was wrong. Try it:

```bash
curl -X POST http://127.0.0.1:8080/issues \
  -H "Content-Type: application/json" \
  -d '{"title": "only"}'   # missing `priority` — a 400, not a crash
# {"status":400,"title":"Bad Request",
#  "detail":"Invalid request body: missing key 'priority' at top level"}
```

Nothing in your handler catches either case — they never reach it. The
handler body only ever runs once `body` is a real, valid `NewIssue`. The
415 says so explicitly, naming what it would have accepted (the slashes come
back JSON-escaped, which any JSON parser undoes):

```
{"status":415,"title":"Unsupported Media Type","detail":"Unsupported Media Type: 'text\/plain' — this route accepts application\/json or application\/x-www-form-urlencoded"}
```
