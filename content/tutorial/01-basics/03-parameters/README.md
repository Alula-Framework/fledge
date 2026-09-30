---
title: Path and query parameters
description: Typed extraction from the URL, before the handler body runs.
order: 3
---

```swift
@GetRoute("/issues/:number")
func show(_ context: RequestContext, number: Int) -> String {
    "issue #\(number)"
}
```

`:number` in the route pattern names a path segment, and a handler parameter
with the same label receives it — already an `Int`. The label *is* the segment
it binds to, so the two can't drift apart: write `id:` against `:number` and
the build fails, naming the segments the path does declare.

Try it: `/issues/42` answers `issue #42`. `/issues/abc` never reaches your
handler at all:

```bash
curl -i http://127.0.0.1:8080/issues/abc
```
```
HTTP/1.1 400 Bad Request
Content-Type: application/problem+json

{"status":400,"title":"Bad Request","detail":"path parameter 'number' is not a valid Int: 'abc'"}
```

A real `400` naming the parameter and the type it wanted — not a crash, and
not a `0`. `String`, the integer types, `Double`, `Bool` and `UUID` are
understood out of the box; a type of your own conforms to
`PathParameterConvertible` (one failable initializer), so the rule for what a
segment may be — a slug's allowed characters, a tenant name — is written once,
at the edge, instead of at the top of every handler that receives it.

That keeps two failures apart that look alike: "that wasn't a number" is the
framework's `400`, before your code runs; "no issue has that number" is yours
to answer, and needs somewhere to look the issue *up* — which this tier has no
database for. Part 2 is where queries arrive, and Part 3 wires them into routes
like this one.

The raw form is still there when you want it. `context.pathParam("number")`
returns the segment as a plain `String?`, and
`context.pathParam("number", as: Int.self)` parses it and throws the same
`400` — useful where a handler signature can't reach, like inside middleware.

`show` never reads `context`, so it could leave it out:

```swift
@GetRoute("/issues/:number")
func show(number: Int) -> String {
    "issue #\(number)"
}
```

That builds and answers exactly the same, `400` included, because the
generated route parses `:number`, not your handler. A handler declares
`_ context: RequestContext`, always first, when it reads the request itself:
a header, a cookie, who is signed in. Most handlers in the lessons ahead do,
so they keep it. A WebSocket route always takes it.

## Query parameters

Same idea, different source. A `query:` parameter decodes the query string
into a type of your own, the way a request body decodes (next exercise):

```swift
struct IssueFilters: Decodable {
    var status: String?
    var page: Int?
}

@GetRoute("/issues")
func index(_ context: RequestContext, query: IssueFilters) -> String {
    "issues filtered by status: \(query.status ?? "all"), page \(query.page ?? 1)"
}
```

```bash
curl "http://127.0.0.1:8080/issues?status=open"
# issues filtered by status: open, page 1
curl "http://127.0.0.1:8080/issues?page=2"
# issues filtered by status: all, page 2
curl "http://127.0.0.1:8080/issues?page=two"
# {"status":400,"title":"Bad Request","detail":"query parameter 'page' is not a valid Int"}
```

Optional means optional and non-optional means required. Swift's synthesized
`Decodable` doesn't fall back to a property's default value when a key is
absent — it throws — so `var page: Int?`, with `?? 1` where you use it, is the
spelling for "may be absent", and a `var tenant: String` says the request must
carry it. A value of the wrong type is a `400` naming the parameter either way.

For one value read by hand, `context.request.queryParam("status")` returns the
raw `String?`. It reads from `context.request`, not `context` directly: path
parameters are properties of *this route's match*, query parameters are
properties of *the request itself*, and the API mirrors that distinction
rather than hiding it.
