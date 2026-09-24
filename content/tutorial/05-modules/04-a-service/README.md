---
title: A module that runs something
description: Owning a long-running service, and the provide-vs-take-the-graph rule that keeps composition acyclic.
order: 4
---

Everything a module has provided so far is *inert* — a value someone else calls
into. Some modules own something that runs on its own: a queue consumer, a
cache warmer, a reaper that sweeps expired rows on a timer. Alula has one seam
for that, and it's the last member of the `AlulaModule` protocol you haven't
used: `var service: (any Service)?`.

## The service seam

A `Service` is ServiceLifecycle's contract — a single `run()` method that
starts when the app starts and is cancelled when it shuts down:

```swift
struct HeartbeatService: Service {
    let interval: Duration
    let logger: Logger

    func run() async throws {
        await cancelWhenGracefulShutdown {
            while !Task.isCancelled {
                guard (try? await Task.sleep(for: interval)) != nil else { return }
                logger.info("heartbeat")
            }
        }
    }
}
```

`cancelWhenGracefulShutdown` is the important part. When the app shuts down, the
service group *cancels* each service; wrapping the loop in it turns that signal
into ordinary task cancellation, so `run()` exits by returning rather than by
throwing. A thrown error is a failure that takes the app down with it — which is
right for a crash, wrong for a clean stop.

A module hands its service over by holding it and exposing it:

```swift
struct HeartbeatModule: AlulaModule {
    static var dependencies: [any AlulaModule.Type] { [] }

    let heartbeat: HeartbeatService

    init(configuration: Configuration) {
        let seconds = configuration.get("heartbeat.intervalSeconds", default: 5)
        self.heartbeat = HeartbeatService(
            interval: .seconds(seconds),
            logger: Logger(label: "app.heartbeat"))
    }

    var service: (any Service)? { heartbeat }
}
```

Bootstrap collects the `service` from every module into one `ServiceGroup` and
runs them all. Only modules that own something long-running override `service`;
the default is `nil`, which is why every module you've written until now simply
didn't mention it.

## Order matters, and the DAG can't express it

A `ServiceGroup` starts services in one order and shuts them down in reverse —
and the order that matters isn't the dependency DAG. The HTTP transport doesn't
*depend* on the database pool; the requests do. So a module says where its
service sits with `serviceShutdownPhase`:

- `.infrastructure` — pools, buses, caches. Started first, shut down **last**,
  because everything else borrows them.
- `.standard` — the default. Ordinary background work: schedulers, reapers, a
  heartbeat.
- `.inbound` — anything that accepts work from outside, like the HTTP
  transport. Started last, shut down **first**, so nothing new arrives while
  the system is being taken apart.

A heartbeat is ordinary work, so the default `.standard` is correct and the
module says nothing. You reach for this only when getting teardown wrong is
expensive — the framework's own transport declares `.inbound` precisely so a
request holding a database connection can't be cut off underneath by the pool
closing first.

## The one rule that keeps composition acyclic

There's a constraint you'll meet the first time a module needs the whole
component graph. A module can do one of two things with the graph, never both:

- **Provide a value the graph is built from.** A `TokenValidator`, a
  `JobCoordinator` — a *root* of the graph. The graph is assembled from these,
  so it can't exist yet when your module is built.
- **Take the finished graph.** A module that declares `init(graph: AlulaGraph)`
  is handed the fully-built graph and can reach into it — but then it cannot
  also provide a root, because that would mean the graph depends on a module
  that depends on the graph. A cycle.

The build refuses that cycle *by name* rather than deadlocking at runtime. It's
why Alula's own demo splits its authentication into a `DemoAuthModule` (which
*provides* the `TokenValidator` root) separate from the `AppModule` (which
*takes* the graph): one module trying to do both would be rejected at build
time, and the split says the true thing anyway — choosing how tokens are
validated is a distinct decision from wiring the rest of the app. Keep a
module on one side of that line and composition stays a DAG.

**Try it.** Add `HeartbeatModule` to a `skeleton` project and `swift run`. You'll
see a `heartbeat` log line every few seconds; press Ctrl-C and watch it stop
cleanly — no error, no stack trace — because `cancelWhenGracefulShutdown` turned
the shutdown into a cancellation the loop returns from.
