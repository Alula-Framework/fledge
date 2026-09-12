---
title: Authentication, brought rather than built
description: The TokenValidator seam, sessions vs. bearer tokens, a real login flow.
order: 2
---

Flight does not ship passwords, a login form, or a session store — on
purpose. Rolling your own auth is how applications get broken, and a
framework can't make that safe by trying harder; what it can do is turn a
*real* identity provider into configuration:

```yaml
# flight.yaml
security:
  oidc:
    issuer: "https://example.descope.com"
    audience: "my-flight-app"
```

```swift
modules: [
    FlightWebModule<FlightTransport>.self,
    FlightOIDCModule.self,
    AppModule.self,
]
```

That's the entire integration for any OIDC-compliant provider — Descope,
Keycloak, Auth0, Entra are the same validator with different
configuration values, not separate packages. `FlightOIDCModule` pulls
`FlightSecurityModule` in with it — the security module wires the machinery
but provides no validator on purpose, and `FlightOIDCModule` is the value
that fills that seam with an `OIDCTokenValidator` built from the config
above. The JWKS endpoint is resolved by OIDC discovery automatically;
cryptographic verification is JWTKit's, not hand-rolled here.

## Reading who's making the request

```swift
@GetRoute("/documents")
func documents(_ context: RequestContext) async throws -> Response {
    let principal = try context.requirePrincipal()   // 401 when absent
    return try Response.json(try await repo.all(
        Document.where { $0.ownerID == principal.subject }))
}
```

`requirePrincipal()` throws a 401 for an unauthenticated request;
`context.principal` is the non-throwing form, `nil` rather than thrown, for
routes that behave differently for a guest instead of refusing them
outright. Either way the identity *rides the request context*: the
`Authentication` middleware writes it onto the copy of `RequestContext` it
passes downstream, so a handler reads it straight off `context` with nothing
to resolve and nothing shared between requests. (It used to live in a
`PrincipalHolder` resolved per request as a `.scoped` component — a scope
kind that no longer exists, because a typed field on the context is where
per-request state belongs now.)

Service code that shouldn't take a principal parameter reads the *ambient*
identity instead — `Principal.current`, a task-local the handler binds for
the duration of a call with `context.withPrincipal { }`:

```swift
@GetRoute("/documents")
func documents(_ context: RequestContext) async throws -> Response {
    try await context.withPrincipal {
        .json(try await documents.currentUsersDocuments())
    }
}

@Service
struct DocumentService {
    @Inject var repo: DocumentRepository

    func currentUsersDocuments() async throws -> [Document] {
        guard let principal = Principal.current else { throw SecurityError.unauthenticated }
        return try await repo.all(Document.where { $0.ownerID == principal.subject })
    }
}
```

The task-local propagates to structured child tasks but deliberately not
across `Task.detached` — a background job should not silently inherit the
requester's identity.

A `struct`, not a `final class`: `@Service`'s expansion requires
`Sendable`, and a class holding a mutable `@Inject` property cannot be
— the error names `Sendable` at the macro rather than at the property, so
it reads more mysteriously than it is. Value types are the default shape
for components across Flight for exactly this reason.

`DocumentService` injects only `DocumentRepository` — a scanned
`@Repository` the build plugin can see. When a component instead injects a
value a *module* provides rather than a scanned annotation — the
`any TokenValidator` a WebSocket upgrade handler needs, say — mark that one
`// flight:hand-registered`:

```swift
// flight:hand-registered
@Inject var validator: any TokenValidator
```

The comment is load-bearing rather than decorative. The build plugin can't
see a module-provided value's origin, so an unmarked `@Inject` of a type it
never scanned draws a warning that resolution will fail at startup. The
marker is how you say "I know, it's wired by a module" — and it's a warning
worth keeping, since the same message means a genuine mistake whenever the
type *isn't* provided anywhere.

## Bearer tokens are the default seam, not the only one

`OIDCTokenValidator` — what the config above wires up — validates a JWT.
Underneath, it satisfies one narrow protocol:

```swift
public protocol TokenValidator {
    func validate(_ token: String) async throws -> Principal
}
```

A provider that isn't a JWT at all — an opaque session token looked up
against your own store, say — is the same seam, conformed to directly:

```swift
struct OpaqueTokenValidator: TokenValidator {
    func validate(_ token: String) async throws -> Principal {
        let session = try await sessions.lookup(token)
        return Principal(subject: session.userID, roles: session.roles)
    }
}
```

Both shapes end at the same place — a `Principal`, read the same way by
every handler and service — which is the actual design: Flight standardizes
*what a validated identity looks like once you have one*, and stays
deliberately agnostic about whether that identity came from a signed
bearer token or a server-side session lookup.

You supply that validator the same way `FlightOIDCModule` supplies its own:
as a module value with an *explicit* type annotation, which the composition
root matches to `FlightSecurityModule`'s `validator:` parameter by type:

```swift
struct AuthModule: FlightModule {
    let tokenValidator: any TokenValidator = OpaqueTokenValidator()
}
```

```swift
modules: [
    FlightWebModule<FlightTransport>.self,
    FlightSecurityModule.self,   // the machinery, minus the validator
    AuthModule.self,             // your validator, provided as a value
    AppModule.self,
]
```

List `FlightSecurityModule` itself here rather than `FlightOIDCModule` — the
security module wires the middleware and takes whatever `(any TokenValidator)`
the composition finds, and `FlightSecurityModule` cannot even be built
without one, so a forgotten validator fails loudly at startup rather than at
the first request. The annotation is required: `let tokenValidator = OpaqueTokenValidator()`
leaves the source scanner nothing to match against `validator: any TokenValidator`,
so it must read `let tokenValidator: any TokenValidator = …`.

## Enforcement is a separate decision from authentication

`FlightSecurityModule` installs its `Authentication` middleware
automatically — but that middleware always continues, whether or not a
token was presented, so a public route stays public even with the module
installed. Requiring a principal is something the application opts into,
either per route with a handler-level guard (`requirePrincipal()`, as
above) or declaratively by naming a *lane*:

```swift
@Controller("/admin", pipelines: [.authenticated])   // 401 for anonymous
struct AdminController {
    @GetRoute("/status", pipelines: [.public])        // deliberately public, and says so
    func status(_ context: RequestContext) -> Response { .text("ok") }
}
```

`.authenticated` is one of two canonical lanes `FlightSecurityModule`
declares. A lane *is* the whole middleware stack for a route naming it, so
this one starts with `Authentication` and ends with `RequireAuthentication`:
the route establishes the identity it then requires, without depending on
the default lane it replaced. `.authentication` is the other — identity
established, nobody rejected — for a route that serves signed-in and
anonymous callers differently.

There's no ordering to get right by hand anymore. Lanes are declared with
`MiddlewareRegistration.lane(_:_:)` and *compose* across modules rather than
running in whatever order the `modules:` list happened to name them:
`FlightSecurityModule` contributes `Authentication` and
`RequireAuthentication` to the `.authenticated` lane, a module of your own
can add to it, and the composition root folds every contribution into one
stack. The old `container.pipeline { RequireAuthentication.self }` — which
worked only because `FlightSecurityModule.configure` had registered
`Authentication` before `AppModule.configure` ran — is gone with the
container.

Authorization stays in the handler: `requireRole` and `requireScope` depend
on a value no lane can describe. Answering a request `RequireAuthentication`
rejects always carries an RFC 6750 `WWW-Authenticate: Bearer` challenge;
`SecurityError.unauthenticated` and `.forbidden` thrown from a handler render
as the generic 401/403 either way.
