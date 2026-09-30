---
title: A module that runs something
description: Owning a long-running service, and the provide-vs-take-the-graph rule that keeps composition acyclic.
order: 4
---

Everything a module has provided so far is *inert* — a value someone else calls
into. Some modules own something that runs on its own: a queue consumer, a
cache warmer, a reaper that sweeps expired rows on a timer. Alula has one seam
for that, a part of the `AlulaModule` protocol you haven't used yet:
`var service: (any Service)?`.

## The service seam

A `Service` here is ServiceLifecycle's protocol — a single `run()` method that
starts when the app starts and is cancelled when it shuts down. It is not the
`@Service` annotation you've put on types for the graph: annotating a type
`@Service` builds it and makes it injectable, and starts nothing. A lifecycle
`Service` is something that runs, and the only way it runs is a module handing
it over.

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

Both ways out of `run()` mean something, and the report on exit says which
happened. A service that throws after the app has been up stops it with the
module named and the error underneath:

```
alula: stopped after running 4m 07s: HeartbeatModule failed.
error: [ALU-LIFE-8005] HeartbeatModule failed after running 4m 07s
```

A service that *returns* while the app is still running — a loop that ended,
a stream that finished — stops it too: "HeartbeatModule's service ended on its
own", reported as `ALU-LIFE-8006`, "HeartbeatModule's service returned without
throwing". Returning is only clean when shutdown asked for it,
which is what `cancelWhenGracefulShutdown` arranges. A service that is
genuinely a bounded job — an import that finishes — says so with
`serviceCompletion: .endsApp` on its module, and then finishing shuts the app
down gracefully instead.

A module hands its service over by holding it and exposing it:

```swift
struct HeartbeatModule: AlulaModule {
    static var dependencies: [any AlulaModule.Type] { [] }

    let heartbeat: HeartbeatService

    init(configuration: Configuration) {
        let seconds = configuration.get("heartbeat.interval-seconds", default: 5)
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

The build refuses that cycle *by name* rather than deadlocking at runtime:
`ALU-LIFE-8001` prints the shortest cycle with the value each edge carries, so
you can see which provided value closes the loop. It's
why Alula's own demo splits its authentication into a `DemoAuthModule` (which
*provides* the `TokenValidator` root) separate from the `AppModule` (which
*takes* the graph): one module trying to do both would be rejected at build
time, and the split says the true thing anyway — choosing how tokens are
validated is a distinct decision from wiring the rest of the app. Keep a
module on one side of that line and composition stays a DAG.

**Try it.** Add `HeartbeatModule` to a `skeleton` project and `swift run`. You'll
see a `heartbeat` log line every few seconds; press Ctrl-C and watch it stop
cleanly — no error, no stack trace — because `cancelWhenGracefulShutdown` turned
the shutdown into a cancellation the loop returns from. Set
`heartbeat.interval-seconds: 2` in `alula.yaml` — or
`ALULA_HEARTBEAT_INTERVAL_SECONDS=2` in the environment — and the beat
quickens.
