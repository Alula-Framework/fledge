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

A `String` becomes `text/plain`; a `Codable` type becomes JSON — the return
type decides the `Content-Type`, so the two don't need different handler
shapes:

```swift
struct Greeting: Codable { let message: String }

@GetRoute("/hello-json")
func helloJSON(_ context: RequestContext) -> Greeting {
    Greeting(message: "hello, alula")
}
```

For anything else — a specific status code, a header, a streaming body —
construct a `Response` directly (see
[Requests & Responses](/guides/requests-and-responses)).

## Path and query parameters

```swift
@GetRoute("/posts/:id")
func show(_ context: RequestContext) async throws -> Post {
    guard let idText = context.pathParam("id"), let id = UUID(uuidString: idText) else {
        throw HTTPError(.badRequest, "malformed id")
    }
    guard let post = try await repo.one(Post.where { $0.id == id }) else {
        throw HTTPError(.notFound, "no such post")
    }
    return post
}
```

`:id` in the pattern names a path segment; `context.pathParam("id")` reads
it back as a plain `String?` — Alula never guesses whether `:id` means a
`UUID`, an `Int`, or a slug, so converting it is always your own explicit
call. The shape above — extract as `String?`, convert, `guard`-else-throw —
is the one you'll write for every typed path parameter in every Alula app.

Query parameters read the same way, from the request rather than the
route's match:

```swift
@GetRoute("/posts")
func index(_ context: RequestContext) -> String {
    let onlyPublished = context.request.queryParam("published") == "true"
    return "published only: \(onlyPublished)"
}
```

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
construct. It's the single access point for the current request: path
parameters, container components scoped to this request (`@Inject`
works the same way inside a controller as anywhere else), and the request
logger.

## Where to go next

- [Requests & Responses](/guides/requests-and-responses) — status codes,
  content negotiation, and shaping an error on purpose.
- [Configuration](/guides/configuration) — `@ConfigValue`/`@Settings`, and
  the three layers a value can come from.

[Part 1 of the tutorial](/tutorial/01-basics) builds these same ideas as
runnable exercises, one concept at a time.
