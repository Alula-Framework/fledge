---
title: Cookies and redirects
description: A progressive-enhancement login flow — Set-Cookie, See Other, and no JavaScript.
order: 6
---

A cookie goes out by decorating a response, not by building headers:

```swift
@PostRoute("/login")
func logIn(_ context: RequestContext, body: LoginForm) -> Response {
    Response.seeOther("/me")
        .settingCookie(Cookie(name: "who", value: body.name, maxAge: .seconds(3600)))
}
```

and comes back in off the request:

```swift
@GetRoute("/me")
func me(_ context: RequestContext) -> String {
    guard let who = context.request.cookie("who") else {
        return "not logged in"
    }
    return "hello, \(who)"
}
```

That is the entire loop. `LoginForm` is a plain `Decodable`, so — exactly
as in the request-bodies exercise — this handler serves an HTML `<form
method="post">` and a JSON client identically, with no JavaScript
anywhere.

```bash
curl -i -X POST 127.0.0.1:8080/login \
  -H "Content-Type: application/x-www-form-urlencoded" -d "name=Ada"
```
```
HTTP/1.1 303 See Other
Location: /me
Set-Cookie: who=Ada; Path=/; Max-Age=3600; HttpOnly; SameSite=Lax
```

## Why `seeOther` and not just a 200

`Response.seeOther(_:)` is a `303`, and the status matters: it turns the
POST into a GET of `Location`. Reload the page you land on and you re-run
that GET, not the POST — so no browser ever offers to re-submit the login.
This is the redirect a form wants, and the reason it exists as its own
constructor rather than something you assemble from a status code and a
header.

## The defaults are the interesting part

Look at what came back on the wire against what the code asked for. The
call named a name, a value, and a lifetime; the cookie arrived with
`Path=/`, `HttpOnly`, and `SameSite=Lax` as well:

- **`HttpOnly` is on by default.** The cookie is unreadable from
  JavaScript, so an injected script can't exfiltrate it. Opting *out* is
  possible and deliberate; forgetting to opt in is not a mistake you can
  make here.
- **`SameSite=Lax` by default**, which is what stops another origin's form
  from POSTing as you while still letting an ordinary link into your site
  arrive logged in.
- **`Secure` is *off* by default**, and this is the one asymmetry worth
  understanding rather than memorising. It is left to you because a
  development server on loopback has no TLS, and a `Secure` cookie over
  plain HTTP is silently never set at all — a failure that looks like your
  login logic being broken. An explicitly insecure cookie in development
  beats a mystery in every environment. Set `isSecure: true` in
  production.

## Clearing one

There is no "delete cookie" on the wire — a cookie is deleted by overwriting
it with an empty value that has already expired. `Cookie.expiring(_:)` builds
exactly that, and `expiringCookie(_:)` on a response sets it:

```swift
@PostRoute("/logout")
func logOut(_ context: RequestContext) -> Response {
    Response.seeOther("/me").expiringCookie("who")
}
```
```
Set-Cookie: who=; Path=/; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; HttpOnly; SameSite=Lax
```

`Max-Age=0` tells the browser to drop it immediately, and the past `Expires`
says the same to a client that only reads that. The path has to match the one
it was set with, which is one more reason to leave `path` alone unless you
have a reason: a cookie set at `/` and cleared at `/logout` is a cookie that
never goes away. `expiringCookie` defaults to `/` for that reason, and takes
`path:` and `domain:` for a cookie that was set with others.

## When the cookie *is* the login

A name in a cookie is fine for learning how cookies behave, and nothing more:
the client can set `who` to anything it likes. Real sign-in state belongs in a
session — `AlulaSessionsModule` keeps the values on the server under an id the
cookie carries, regenerates that id when someone signs in, and gives a handler
`context.session`. [Authentication](/tutorial/03-intermediate/02-authentication)
builds on it.
