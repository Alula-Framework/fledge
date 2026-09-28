---
title: Deployment
description: systemd, Docker, stripping your release binary, and a reverse proxy in front of it.
order: 9
---

An Alula app is a single statically-linkable executable once built for
release, and deploying it is mostly ordinary. The one thing worth knowing
before the rest: bootstrap already listens for the signals a process manager
sends.

```swift
gracefulShutdownSignals: [.sigterm, .sigint]
```

That's Alula's own bootstrap, handing shutdown to `ServiceLifecycle`
rather than reinventing it. `SIGTERM` is exactly what `systemctl stop` and
`docker stop` send by default, so an Alula app under either one drains
in-flight requests and stops cleanly with no extra configuration — the
same graceful-shutdown path this tutorial's streaming and SSE exercises
already relied on when a client disconnected mid-response.

## The image `alula new` already wrote

Every project `alula new` generates has a `Dockerfile` at its root: a
two-stage build that compiles with the full toolchain
(`swift build -c release --static-swift-stdlib`) and copies the executable —
plus the `migrate` tool, in a project that has migrations — and the
`alula*.yaml` files into a small `ubuntu:noble` image, running as an
unprivileged user. It sets two things worth knowing about:

```dockerfile
ENV ALULA_ENV=prod
# Listen beyond the container's own loopback.
ENV ALULA_SERVER_HOST=0.0.0.0
```

`ALULA_ENV=prod` selects `alula-prod.yaml` on top of `alula.yaml`. It also
declares a non-development environment, so the actuator dashboard and the
OpenAPI document are off, and a project that includes the mail module (the
`demo` tier) needs a real transport — `AlulaMailSMTPModule` and `mail.smtp.*`
— or refuses to start with `ALU-CONFIG-5013` rather than send nothing. The second
line is the one a hand-written Dockerfile forgets: `server.host` defaults to
`127.0.0.1`, which inside a container is reachable from nothing but the
container itself, so nothing answers on the port you published.
The entrypoint is the executable itself, not a shell, so `docker stop`'s
`SIGTERM` reaches the app directly. Migrations run from the same image:

```bash
docker build -t myservice .
docker run -p 8080:8080 -e ALULA_DATASOURCE_PRIMARY_URL=postgres://… myservice
docker run --entrypoint ./migrate -e ALULA_DATABASE_URL=postgres://… myservice apply
```

`--static-swift-stdlib` trades a larger binary for not needing the Swift
runtime installed in the runtime image at all, which is what lets the
second stage be a plain Ubuntu. The file is yours to change. One change
worth considering: `-c release` alone still leaves debug symbols in the
binary — tens of megabytes once Hangar, Channels, and everything else this
tutorial covered are linked in — and a `strip` of the copied executable
removes them from what ships. Keep an unstripped build in CI if you ever want
a symbolicated crash backtrace.

## Draining, and a deadline

A graceful stop has two settings, and both are worth setting on day one:

```yaml
lifecycle:
  drain-seconds: 5               # readiness says 503 this long before the listener closes
  shutdown-timeout-seconds: 25   # below the orchestrator's own kill deadline
```

On `SIGTERM`, `/actuator/health/ready` starts answering `503` at once while
the server keeps serving for `drain-seconds`, so a load balancer stops sending
traffic before the listener goes away. Then the modules stop in order — the
HTTP transport first, the database pools last — and the queue worker hands
running jobs back before the deadline rather than having them cancelled
mid-flight. A shutdown that overruns `shutdown-timeout-seconds` is not
reported as a clean stop: it prints `alula: shutdown timed out.` with the
modules that were still running (`ALU-LIFE-8004`) and exits 1.

## systemd, if you're not containerizing

```ini
[Unit]
Description=MyService
After=network.target

[Service]
WorkingDirectory=/opt/myservice
ExecStart=/opt/myservice/MyService
Restart=on-failure
Environment=ALULA_ENV=prod
User=myservice

[Install]
WantedBy=multi-user.target
```

`systemctl stop myservice` sends exactly the `SIGTERM` Alula's bootstrap is
already listening for — nothing in this unit file does anything special
for graceful shutdown; the framework's bootstrap does that part.
`WorkingDirectory` matters for a different reason: `alula.yaml` and its
overlays are read from the working directory, so it is where they go.

## A reverse proxy in front

Alula can terminate TLS itself — name a certificate chain and a key under
`server.tls` and it serves HTTPS — but a proxy in front is still the usual
shape, because it also renews the certificate and gives you one place for a
public hostname:

```
app.example.com {
    reverse_proxy localhost:8080
    encode gzip
}
```

Behind a proxy, tell Alula which one to trust (`web.trusted-proxies`), so
`context.clientAddress` and rate limiting see the client rather than the proxy,
and a WebSocket handshake's origin check sees the public host.

Caddy provisions and renews TLS automatically for a real hostname, which
is the entire config — no separate certbot step, no renewal cron job. The
one thing worth getting right on day one: a bare `localhost` or an IP
literal in place of `app.example.com` makes Caddy skip automatic HTTPS
entirely (there's no public hostname to issue a certificate for), so
local testing against a raw address and production against a real domain
need genuinely different Caddyfiles, not the same one with a placeholder
swapped in.
