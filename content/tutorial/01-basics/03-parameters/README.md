---
title: Path and query parameters
description: Typed extraction from the URL, before the handler body runs.
order: 3
---

```swift
@GetRoute("/issues/:number")
func show(_ context: RequestContext) -> String {
    guard let number = context.pathParam("number") else {
        return "missing number"  // in practice: see the exercise on HTTPError
    }
    return "issue #\(number)"
}
```

`:number` in the route pattern names a path segment;
`context.pathParam("number")` reads it back. It's always a plain `String?`
— Alula doesn't guess whether `:number` means a `UUID`, an `Int`, or a
slug, so converting it to the type you actually want is your call, made
explicitly:

```swift
@GetRoute("/issues/:number")
func show(_ context: RequestContext) throws -> String {
    guard let text = context.pathParam("number"), let number = Int(text) else {
        throw HTTPError(.badRequest, "issue number must be an integer")
    }
    return "issue #\(number)"
}
```

Try it: `/issues/42` answers `issue #42`, and `/issues/abc` answers a real
`400` with your message in it, not a crash and not a `0`.

This shape — extract as `String?`, convert, `guard`-else-throw — is the
one you'll write for every typed path parameter in every Alula app. It
looks like more code than a framework that guesses your type for you, and
it is: in exchange, "that wasn't a number" and "no issue has that number"
stay two different, explicit, named failures instead of one
framework-generated 400 that doesn't say which. (The second half of that
pair needs somewhere to look the issue *up*, which this tier has no
database for — Part 2 is where queries arrive, and Part 3 wires them into
routes like this one.)

## Query parameters

Same shape, different source:

```swift
@GetRoute("/issues")
func index(_ context: RequestContext) -> String {
    let status = context.request.queryParam("status") ?? "all"
    return "issues filtered by status: \(status)"
}
```

```bash
curl "http://127.0.0.1:8080/issues?status=open"
# issues filtered by status: open
curl "http://127.0.0.1:8080/issues"
# issues filtered by status: all
```

`queryParam` reads from `context.request`, not `context` directly — path
parameters are properties of *this route's match*, query parameters are
properties of *the request itself*, and the API mirrors that distinction
rather than hiding it.
