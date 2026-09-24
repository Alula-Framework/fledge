---
title: Deployment
description: systemd, Docker, stripping your release binary, and a reverse proxy in front of it.
order: 9
---

An Alula app is a single statically-linkable executable once built for
release — nothing about deploying it is specific to this framework except
one thing worth knowing before the rest: bootstrap already listens for
the signals a process manager sends.

```swift
gracefulShutdownSignals: [.sigterm, .sigint]
```

That's Alula's own bootstrap, handing shutdown to `ServiceLifecycle`
rather than reinventing it. `SIGTERM` is exactly what `systemctl stop` and
`docker stop` send by default, so an Alula app under either one drains
in-flight requests and stops cleanly with no extra configuration — the
same graceful-shutdown path this tutorial's streaming and SSE exercises
already relied on when a client disconnected mid-response.

## Building a release binary

```dockerfile
FROM swift:6.3 AS build
WORKDIR /build
COPY Package.swift Package.resolved ./
COPY Sources ./Sources
RUN swift build -c release --static-swift-stdlib
RUN strip .build/release/App

FROM swift:6.3-slim
COPY --from=build /build/.build/release/App /usr/local/bin/app
EXPOSE 8080
CMD ["/usr/local/bin/app"]
```

`-c release` alone still leaves debug symbols in the binary — often
tens of megabytes for a real app once Hangar, Channels, and everything
else this tutorial covered are linked in. `strip` removes them from the
binary that actually ships; keep an unstripped copy in CI if you ever
want a symbolicated crash backtrace. `--static-swift-stdlib` trades a
larger binary for not needing the Swift runtime installed in the runtime
image at all — worth it for a minimal container, not mandatory if your
runtime image already carries a matching Swift installation.

## systemd, if you're not containerizing

```ini
[Unit]
Description=App
After=network.target

[Service]
ExecStart=/usr/local/bin/app
Restart=on-failure
Environment=ALULA_ENV=prod
User=app

[Install]
WantedBy=multi-user.target
```

`systemctl stop app` sends exactly the `SIGTERM` Alula's bootstrap is
already listening for — nothing in this unit file does anything special
for graceful shutdown; that part was earned back in `Bootstrap.swift`.

## A reverse proxy in front

Alula binds a plain HTTP port; TLS and a public hostname are a proxy's
job, not this process's:

```
app.example.com {
    reverse_proxy localhost:8080
    encode gzip
}
```

Caddy provisions and renews TLS automatically for a real hostname, which
is the entire config — no separate certbot step, no renewal cron job. The
one thing worth getting right on day one: a bare `localhost` or an IP
literal in place of `app.example.com` makes Caddy skip automatic HTTPS
entirely (there's no public hostname to issue a certificate for), so
local testing against a raw address and production against a real domain
need genuinely different Caddyfiles, not the same one with a placeholder
swapped in.
