---
title: Deployment
description: systemd, Docker, stripping your release binary, and a reverse proxy.
order: 5
category: Alula
---

An Alula app is a single statically-linkable executable once built for
release — nothing about deploying it is specific to this framework except
one thing worth knowing before the rest: bootstrap already listens for
the signals a process manager sends.

```swift
gracefulShutdownSignals: [.sigterm, .sigint]
```

`SIGTERM` is exactly what `systemctl stop` and `docker stop` send by
default, so an Alula app under either one drains in-flight requests and
stops cleanly with no extra configuration.

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

`-c release` alone still leaves debug symbols in the binary — often tens
of megabytes for a real app. `strip` removes them from what actually
ships; keep an unstripped copy in CI if you ever want a symbolicated
crash backtrace. `--static-swift-stdlib` trades a larger binary for not
needing the Swift runtime installed in the runtime image at all.

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
for graceful shutdown; that part is earned by the framework itself.

## A reverse proxy in front

```
app.example.com {
    reverse_proxy localhost:8080
    encode gzip
}
```

Caddy provisions and renews TLS automatically for a real hostname — no
separate certbot step, no renewal cron job. The one thing worth getting
right on day one: a bare `localhost` or an IP literal in place of a real
hostname makes Caddy skip automatic HTTPS entirely, so local testing and
production need genuinely different Caddyfiles, not the same one with a
placeholder swapped in.

## Where to go next

- [Configuration](/guides/configuration) — `alula.yaml`,
  `alula-{env}.yaml`, and the `ALULA_ENV` this systemd unit sets.
- [The actuator](/tutorial/03-intermediate/06-actuator) — the health
  endpoint a load balancer or orchestrator should actually probe.

[Part 4 of the tutorial](/tutorial/04-advanced/09-deployment) covers this
as the tutorial's own closing exercise.
