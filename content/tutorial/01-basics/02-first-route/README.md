---
title: Your first route
description: "@Controller and @GetRoute, and why there is no route table to find."
order: 2
---

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

Create this as `Sources/MyService/Controllers/GreetingController.swift` in
your project, run it with `alula dev`, and ask for it:

```bash
curl http://127.0.0.1:8080/hello
# hello, alula
```

No registration call, no route table entry, nothing added to `AppModule`.
`@Controller` marks the type; `@GetRoute` marks the method; the
registration plugin (from the previous exercise) finds both at build time
and generates the wiring. If you're looking for "where do I add my new
route," the answer is: you don't, past writing the method.

## What a handler can return

A `String` becomes a `text/plain` body with a `200`. For a domain type of
your own, declare `ResponseEncodable` alongside `Codable` and it becomes
JSON:

```swift
struct Greeting: Codable, ResponseEncodable {
    let message: String
}

@GetRoute("/hello-json")
func helloJSON(_ context: RequestContext) -> Greeting {
    Greeting(message: "hello, alula")
}
```

```bash
curl http://127.0.0.1:8080/hello-json
# {"message":"hello, alula"}
```

`Codable` alone isn't enough, and the compiler says so rather than
silently serializing something unintended: *"requires that 'Greeting'
conform to 'ResponseEncodable'."* The conformance is empty in practice —
`ResponseEncodable` has a default implementation for anything `Encodable`,
so writing it is a declaration of intent ("this type is something I return
from a handler"), not work. `String`, `Data`, arrays, dictionaries, and
`Optional` already conform, which is why the first example needed nothing.

The response's `Content-Type` follows the return type — a `String` and a
`Codable` type don't need different handler shapes to get different
serialization, and you never construct a `Response` by hand unless you
need to (status codes and headers are next). Two more conveniences worth
knowing now: a handler returning `Void` answers `204`, and one returning a
`nil` optional answers `404`.

## `RequestContext`

Every handler method takes one as its first parameter (Alula resolves it
for you — it's never something you construct). It's your access point for
everything about the current request: the request itself, its path
parameters, and the logger. What a handler *depends on* — a service, a
repository — isn't on it: those are `@Inject` properties of the controller,
built once (the configuration exercise injects its first one). The next two exercises are about what a request brings with it.
