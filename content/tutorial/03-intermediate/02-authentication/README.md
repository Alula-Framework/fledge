---
title: Authentication, brought rather than built
description: The TokenValidator seam, sessions vs. bearer tokens, a real login flow.
order: 2
---

Alula ships the parts of authentication that are easy to get subtly wrong —
and leaves the accounts themselves, the users table and what a user *is*, to
your application. The parts come in two shapes, and both end in the same
`Principal`:

- **A token someone else issued.** An API called with a bearer token from an
  identity provider turns that provider into configuration:

  ```yaml
  # alula.yaml
  security:
    oidc:
      issuer: "https://example.descope.com"
      audience: "my-alula-app"
  ```

  ```swift
  modules: [
      AlulaWebModule<AlulaTransport>.self,
      AlulaOIDCModule.self,
      AppModule.self,
  ]
  ```

- **A browser signing in.** `AlulaSessionsModule` keeps server-side sessions
  behind a cookie; `AlulaPasswordSignInModule` checks passwords against your
  own accounts (hashed with Argon2id, attempts throttled) and
  `AlulaOIDCSignInModule` sends the browser to an external provider instead —
  the same routes and the same front end either way, so moving from your own
  accounts to Keycloak or Entra later is a change to one line of `modules:`.
  CSRF protection, one-time sign-in links and "sign out everywhere" ride on
  the same session. `alula generate auth` writes the accounts part into your
  project — registration, email verification and password reset over
  Postgres — as code you own and can change.

The bearer path first, since it is the smallest. That `AlulaOIDCModule` line
is the entire integration for any OIDC-compliant provider — Descope,
Keycloak, Auth0, Entra are the same validator with different configuration
values, not separate packages. `AlulaOIDCModule` pulls `AlulaSecurityModule`
in with it — the security module wires the machinery but provides no
validator on purpose, and `AlulaOIDCModule` is the value that fills that seam
with an `OIDCTokenValidator` built from the config above. The JWKS endpoint is
resolved by OIDC discovery automatically; cryptographic verification is
JWTKit's, not hand-rolled here.

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

A `struct`, not a `final class`: every component ends up in the composition
root's graph, which crosses into `@Sendable` route closures, so a component
has to be `Sendable` — and a class holding an `@Inject var` isn't. The
compiler reports it inside the generated composition root, as `capture of
'graph' with non-Sendable type 'AlulaGraph' in a '@Sendable' closure`, rather
than at your class, so it reads more mysteriously than it is. Value types are
the default shape for components across Alula for exactly this reason.

`DocumentService` injects only `DocumentRepository` — a scanned
`@Repository`. A component can just as well inject a value a *module*
provides — the `any TokenValidator` a WebSocket upgrade handler needs, say —
and the composition root wires it by type. You'll see those properties marked
in the templates:

```swift
// alula:hand-registered
@Inject var validator: any TokenValidator
```

The comment records that the value comes from a module rather than a scanned
annotation. In an application the build needs no such hint — it sees every
module's values, and a type nothing provides is a build error
(`ALU-DI-1001`), marker or not. It matters in two places: in a library target,
which can't see the modules it will run under and warns (`ALU-DI-1009`) about
an injection nothing in its scan provides; and on a protocol-typed
`@Inject`, where it stops the build from bridging the protocol to a scanned
conformer that would collide with the module's value.

## Bearer tokens are the default seam, not the only one

`OIDCTokenValidator` — what the config above wires up — validates a JWT.
Underneath, it satisfies one narrow protocol:

```swift
public protocol TokenValidator: Sendable {
    func validate(_ token: String) async throws -> Principal
}
```

A provider that isn't a JWT at all — an opaque session token looked up
against your own store, say — is the same seam, conformed to directly:

```swift
struct OpaqueTokenValidator: TokenValidator {
    func validate(_ token: String) async throws -> Principal {
        let session = try await sessions.lookup(token)
        return Principal(subject: session.userID, issuer: "myapp", roles: session.roles)
    }
}
```

Both shapes end at the same place — a `Principal`, read the same way by
every handler and service — which is the actual design: Alula standardizes
*what a validated identity looks like once you have one*, and stays
deliberately agnostic about whether that identity came from a signed
bearer token or a server-side session lookup.

You supply that validator the same way `AlulaOIDCModule` supplies its own:
as a module value with an *explicit* type annotation, which the composition
root matches to `AlulaSecurityModule`'s `validator:` parameter by type:

```swift
struct AuthModule: AlulaModule {
    let tokenValidator: any TokenValidator = OpaqueTokenValidator()
}
```

```swift
modules: [
    AlulaWebModule<AlulaTransport>.self,
    AlulaSecurityModule.self,   // the machinery, minus the validator
    AuthModule.self,             // your validator, provided as a value
    AppModule.self,
]
```

List `AlulaSecurityModule` itself here rather than `AlulaOIDCModule` — the
security module wires the middleware and takes whatever `(any TokenValidator)`
the composition finds. With neither a validator nor sessions nobody could
ever be authenticated, so that combination stops the application at startup
rather than failing at the first request. (With `AlulaSessionsModule` listed,
a validator is optional: an application that only signs browsers in has no
bearer API to validate.) The annotation is required: `let tokenValidator = OpaqueTokenValidator()`
leaves the source scanner nothing to match against `validator: any TokenValidator`,
so it must read `let tokenValidator: any TokenValidator = …`.

## Enforcement is a separate decision from authentication

`AlulaSecurityModule` installs its `Authentication` middleware
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

`.authenticated` is one of two canonical lanes `AlulaSecurityModule`
declares. A lane *is* the whole middleware stack for a route naming it, so
this one starts with `Authentication` and ends with `RequireAuthentication`:
the route establishes the identity it then requires, without depending on
the default lane it replaced. `.authentication` is the other — identity
established, nobody rejected — for a route that serves signed-in and
anonymous callers differently.

There's no ordering to get right by hand. Lanes are declared with
`MiddlewareRegistration.lane(_:_:)` and *compose* across modules rather than
running in whatever order the `modules:` list happened to name them:
`AlulaSecurityModule` contributes `Authentication` and
`RequireAuthentication` to the `.authenticated` lane, a module of your own
can add to it, and the composition root folds every contribution into one
stack.

Roles are declared on the route, next to the endpoint they protect:

```swift
enum AppRole: String, RouteRole { case admin, billing }

@Controller("/admin", roles: [AppRole.admin])
struct AdminController {
    @GetRoute("/invoices", roles: [AppRole.billing])   // needs admin AND billing
    func invoices(_ context: RequestContext) async throws -> [Invoice] { … }
}
```

An anonymous request is a 401; a signed-in one without the role is a 403
naming what would have been enough. What a role can't express stays in the
handler — whether *this* user may see *this* invoice is a fact about data, so
`requirePrincipal()`, `requireRole(_:)` and `requireScope(_:)` are there for
the check that reads a row before it can decide. Answering a request `RequireAuthentication`
rejects always carries an RFC 6750 `WWW-Authenticate: Bearer` challenge;
`SecurityError.unauthenticated` and `.forbidden` thrown from a handler render
as the generic 401/403 either way.

## Signing a browser in

A browser has no bearer token; it has a cookie. List `AlulaSessionsModule`
and the credential check happens once — a password form, an OIDC callback, a
one-time link — after which the `Principal` lives in the session:

```swift
@PostRoute("/login", pipelines: [.default, "csrf"])
func login(_ context: RequestContext, body: LoginForm) async throws -> Response {
    let account = try await accounts.authenticate(body.email, body.password)
    try context.requireSession().signIn(
        Principal(subject: account.id.uuidString, issuer: "myapp", roles: account.roles))
    return .seeOther("/")
}
```

From then on `Authentication` finds the principal in the session on every
request that carries the cookie, and `context.principal`,
`requirePrincipal()`, the `.authenticated` lane and `roles:` work exactly as
they do for a token. `signIn` regenerates the session id every time, so an id
handed out before sign-in is never the one that is signed in afterwards.

You rarely write `login` yourself. `AlulaPasswordSignInModule` provides a
`SignInProvider` that checks the password against a `CredentialStore` you
implement over your own accounts table — two methods, find an account and
save a stronger hash — and `AlulaOIDCSignInModule` provides the same seam over
an external provider, by the authorization-code flow with PKCE. Your sign-in
controller talks to `any SignInProvider`, so it doesn't change when the
provider does. The state-changing routes, sign-in included, go on the `csrf`
lane: `CSRFProtection` refuses a `POST` that doesn't carry the session's own
token, and forcing someone to sign in as the attacker is an attack
`SameSite=Lax` doesn't stop.

For a new application, `alula generate auth` writes all of it into the
project: an `Account` entity and its migration, registration, email
verification and password reset, and an `AccountsModule` that provides the
credential store — code to read and change, not a dependency to configure.
List `AccountsModule.self` in `modules:` afterwards; until you do, the build
says so by name (`ALU-DI-1001`, "`AccountsModule` provides … and is not in
`modules:`").
