---
title: Routing and Controllers
description: "@Controller, path parameters, and how the registration plugin finds your routes."
order: 1
category: Alula
---

A route is a method, marked, on a type, marked:

```swift
import AlulaCore
import AlulaWeb

@Controller
struct GreetingController {
    @GetRoute("/hello")
    func hello(_ context: RequestContext) -> String {
        "hello, alula"
    }
}
```

That's the whole registration. No route table to find and edit, no call
that lists this path anywhere else — `@Controller` marks the type,
`@GetRoute` marks the method, and `AlulaRegistrationPlugin` (a build
plugin, not a runtime scan) finds both at compile time and generates the
wiring. Adding a route means writing a method; it never means finding
where routes are registered.

## What a handler can return

A `String` becomes `text/plain`; a type of your own that declares
`ResponseEncodable` alongside `Codable` becomes JSON — the return type decides
the `Content-Type`, so the two don't need different handler shapes:

```swift
struct Greeting: Codable, ResponseEncodable { let message: String }

@GetRoute("/hello-json")
func helloJSON(_ context: RequestContext) -> Greeting {
    Greeting(message: "hello, alula")
}
```

`Codable` alone is not enough, and the compiler says so: the conformance is
empty in practice, but it is the declaration that this type is something a
handler returns. A handler returning `Void` answers `204`, and one returning a
`nil` optional answers `404`. For anything else — a specific status code, a
header, a streaming body — construct a `Response` directly (see
[Requests & Responses](/guides/requests-and-responses)).

## Path and query parameters

A handler parameter named after a `:segment` receives it, already parsed:

```swift
@GetRoute("/posts/:id")
func show(_ context: RequestContext, id: UUID) async throws -> Post {
    guard let post = try await posts.find(id) else {
        throw HTTPError(.notFound, "no such post")
    }
    return post
}
```

The label *is* the segment it binds to, so the two cannot drift apart: asking
for a segment the path does not declare is a build error naming the ones it
does. A segment that will not parse never reaches the handler — `/posts/abc`
answers `400` with `path parameter 'id' is not a valid UUID: 'abc'`. `String`,
the integer types, `Double`, `Bool` and `UUID` are understood; conform your own
type to `PathParameterConvertible` and the rule for what the segment may be
lives at the edge instead of in every handler.

That leaves one failure per concern, each named: "that wasn't a UUID" is the
framework's 400, and "no post has that id" is your 404.
`context.pathParam("id")` still returns the raw `String?`, and
`context.pathParam("id", as: UUID.self)` parses one where a handler signature
cannot reach — inside middleware, say.

Query parameters decode into a type the same way a body does:

```swift
struct PostFilters: Decodable {
    var published: Bool?
    var page: Int?
}

@GetRoute("/posts")
func index(_ context: RequestContext, query: PostFilters) -> String {
    "published only: \(query.published ?? false), page \(query.page ?? 1)"
}
```

Optional means optional and non-optional means required: a missing required
key, or a value of the wrong type, is a `400` naming the parameter.
`context.request.queryParam("published")` still reads one raw value.

## Grouping routes under a base path

```swift
@Controller("/users")
struct UserController {
    @GetRoute("/")           // → GET /users
    func index(_ context: RequestContext) -> [User] { ... }

    @GetRoute("/:id")        // → GET /users/:id
    func show(_ context: RequestContext) -> User { ... }
}
```

A base path and a mapping's own path concatenate, collapsing a doubled `/`
at the seam; a mapping of exactly `"/"` resolves to the base path itself,
not a trailing-slash variant of it.

## `RequestContext`

Every handler's first parameter, resolved for you — never something you
construct. It's the single access point for the current request: the
`request` itself, its path parameters, the request logger, and what earlier
middleware established — `context.principal` once a request is authenticated,
`context.session` when sessions are on. Dependencies are not on it: a
controller takes those as `@Inject` properties, built once, like any other
component.

## Where to go next

- [Requests & Responses](/guides/requests-and-responses) — status codes,
  content negotiation, and shaping an error on purpose.
- [Configuration](/guides/configuration) — `@ConfigValue`/`@Settings`, and
  the three layers a value can come from.

[Part 1 of the tutorial](/tutorial/01-basics) builds these same ideas as
runnable exercises, one concept at a time.
