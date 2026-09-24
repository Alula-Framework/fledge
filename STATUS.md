# Status

What's actually built, verified, and running, versus what's still just in
`PLAN.md`. Updated as milestones land — see `PLAN.md` §10 for the full
milestone list this maps onto.

## 2026-09-24 — Flight School is now Fledge

The site was renamed Fledge (repo `Alula-Framework/fledge`), and the
framework it teaches was renamed Flight → Alula (alula D45). Every
exercise, the server and the runner now pin alula 0.36.0, alula-data
0.11.0 and hangar 0.9.2, because older tags lack the `alula` product
names. The DocC base paths moved to `fledge/…`, and the databases are
`fledge_seed`, `fledge_dev` and `fledge_ci`. The entries below describe the
same work in the current names.

## Done — M0 fully closed, this time confirmed by real content, not status codes

Per `PLAN.md` §10, M0 is "SvelteKit site rendering guides + tutorial
*text* (no execution); the guides link out to DocC on GitHub Pages."
The tutorial (40 of 41 exercises) and all 13 guides are real and
confirmed working — see below, unchanged from before. The DocC-on-Pages
half is now genuinely confirmed too: after the fix below, checked that
the baked-in `baseUrl` on real deployed pages for all three repos
(`.../alula/AlulaCore/`, `.../hangar/Hangar/`,
`.../alula-data/AlulaCache/`) matches the real served path, and that
the actual JS asset each page requests resolves with 200 — not just the
top-level document. swift-changeset has since been added as a fourth
repo (a user noticed it was missing — Changeset/ValidationRule/
TableModel are taught directly in Part 2 but had no reference docs at
all) and is queued for its own first real run.

The DocC-on-Pages half was prematurely declared done here, twice, on
the strength of a verification pass that only checked HTTP status
codes. **Every DocC page was actually rendering blank** — reported
directly by a user, not caught by anything in this file's own process.
Root cause: DocC's `--transform-for-static-hosting` output is a
client-rendered SPA shell (`<div id="app"></div>`, empty until JS
populates it); the `--hosting-base-path` passed to DocC
(`fledge/reference/alula/$target`) didn't match where the
artifact actually gets served (`fledge/alula/$target` — no
`/reference/` segment, confirmed by checking the real generated file
layout and the index page's own links, both of which agreed with each
other and disagreed with the flag). Every JS/CSS asset the page needed
therefore 404'd, silently, and the page never became more than an empty
shell — a failure mode a status-code check cannot see, because the HTML
document itself still returns 200.

Worse: this workflow already *had* a step named "Smoke-check hosting
base path" meant to catch exactly this, and it didn't, because it only
grepped for the base-path string appearing *somewhere* in the output —
which is always true, since DocC bakes in whatever it's told whether or
not that's where the files end up. Replaced with a check that extracts
the real baked-in `baseUrl` from a generated page and confirms a
directory actually exists where it points; tested directly against
both the broken value (correctly fails) and the fixed one (correctly
passes) before trusting it in CI. Fixed and re-triggered; **not yet
re-verified against live rendered content** — the next update to this
file needs to confirm actual page content this time, not a status
code, before this can honestly be called done again.

**Site.** SvelteKit 5 (Svelte `5.56.1`, verified — not just requested),
`adapter-node`, deployed via `docker compose up -d` (Caddy + site).
Content is markdown, bind-mounted into the container and read per-request
— editing a guide takes effect on the next request, no rebuild. The
exercise pager (`adjacentExercises` in `curriculum.ts`) walks the whole
curriculum flattened, not just the current part, so the last exercise of
one part correctly links into the first exercise of the next — verified
against a production build in both directions, and confirmed it composes
correctly with the "coming soon" placeholder below (a pager can point at
an unwritten exercise; that page still renders, with correct prev/next of
its own).

**Content, real and verified** — grounded directly in alula source and
alula-cli's actual templates/README, not invented:
- Part 0 (Setup), all four exercises: install, `alula new`, project
  anatomy, running locally.
- Part 1 (Alula basics), 8 of 9 exercises: bootstrap/modules, first
  route, path/query parameters, request bodies, responses/HTTPError,
  static assets, middleware, configuration. **`06-cookies` is deliberately
  unwritten** — cookie support landed in alula's source (commit
  `8997a5a`) but no release tag includes it yet (`v0.8.0` predates it), and
  `alula new`'s `Package.swift` resolves `from: "0.7.0"` to the latest
  *tagged* release. Writing this exercise now would document an API a
  learner's own `alula new` can't reach. Revisit once alula cuts its next
  tag; don't write it against `alula`'s HEAD in the meantime.
- Part 2 (Data with Hangar and Changeset), all 12 exercises: entities,
  queries, predicates/`debugSQL`, changesets, associations/`Loadable`,
  preloading, joins/aliases/self-joins, transactions/isolation/retry,
  `Multi`, bulk writes, `alula-data` (migrations/cache/Valkey), and
  diagnostics/`EXPLAIN`. Verified against Hangar `v0.2.1` and
  swift-changeset `v0.1.0` (tagged releases, not their working trees —
  both repos had unrelated in-progress uncommitted changes while this was
  written; tagged-source reads avoided depending on either).
- Part 3 (Intermediate web), all 7 exercises: wiring Hangar's `Repo` into
  Alula's request scope (and the connection-affinity bug that motivates
  it), authentication via `TokenValidator`/OIDC, multipart + resumable
  (tus 1.0) uploads, server-sent events, `@Scheduler`/fleet-wide-once
  scheduling, the actuator's real health/dashboard split, and the three
  real sizes of test.
- Part 4 (Advanced: realtime and beyond), all 9 exercises: raw
  WebSockets vs. Channels, the envelope protocol (join/handle/reply/
  broadcast), HTTP-to-socket fan-out, Presence (metas, state-then-diffs,
  the measured join-storm cost), the four teardown paths, testing
  channels, the PubSub clustering seam, a capstone tying every seam
  together, and deployment. **This completes every part of the tutorial
  curriculum** — Parts 0 through 4, 40 of 41 planned exercises written.
  The one gap is `01-basics/06-cookies`, deliberately deferred — see
  below.
- Parts 3 and 4 both leaned on parallel research agents, one per
  independent subsystem, rather than one sequential pass — each agent's
  findings were cross-checked before anything got written from them,
  same bar as everywhere else in this file. Part 4 specifically used a
  real, unique source: a benchmark project
  (`/home/sinner/swift/SwiftAlula/benchmark/`) that built the same
  realtime issue board twice — once on Alula, once hand-rolled against
  Hummingbird — specifically to measure what Channels is worth. Real
  numbers from it are cited directly in `04-advanced/01-websockets.md`
  and `08-capstone.md` (infrastructure: 0 lines vs. 315; feature layers
  within 7 lines of each other). That benchmark directory is **not a git
  repo** and its own `Package.swift` uses a path dependency on `alula`
  rather than a pinned tag (its own comment already flags this as "wrong
  for a citable result") — the Channels/Presence/PubSub source files it
  exercises haven't changed since well before the tag this tutorial
  otherwise cites, so the numbers hold today, but re-verify before
  citing them again far in the future, and don't treat that directory as
  version-controlled safety net the way every other cited repo is.
- **All 13 planned guides**, every one in `guides.ts` now real: Up and
  Running (Part 0), Routing and Controllers, Requests & Responses,
  Configuration, Testing, Deployment (Alula); Hangar Getting Started,
  Queries, Changesets, Associations & Preloading, Transactions & Multi
  (Hangar); Channels, Presence (Realtime) — repackaging tutorial material
  already verified while writing Parts 1–4, not separately re-verified.
  "Hangar: Getting Started" was also **fixed**: it originally had the
  same two invented-API mistakes as Hangar's README below, inherited
  when it was written before this session's verification pass existed.

**Real bugs found upstream while verifying, not fixed there** (out of
scope — those repos have their own in-progress work and their docs
aren't this repo's to edit; this repo's own content was written against
the verified-correct shape in every case). The count is high enough to
name a pattern rather than treat each as a one-off: across `alula`,
Hangar, and `alula-data`, doc comments, docc catalogues, and READMEs
drift from the code they describe often enough that none of them should
be trusted as a citation on their own — grep the actual declaration, the
actual diagnostic message, or the actual route registration instead.
Specific instances found:
- Hangar's `README.md`: bare `@Column var title: String` (the macro
  requires a string-literal name whenever it's used at all) and
  `@BelongsTo(\.authorID)` (requires the `foreignKey:` label; no
  positional overload exists).
- `alula-data`'s `Docs/migrate.md`: an old standalone-package install
  path (`alula-server/alula-migrate`) contradicting the current
  trait-based one in its own top-level `README.md`.
- `alula`'s `AlulaSecurityCore.docc`: a `security: { issuer, audience }`
  example missing the `oidc:` nesting the actual `@Settings`-bound keys
  require (`security.oidc.issuer`, confirmed by grepping
  `OIDCSecurityConfiguration.swift`'s literal `configuration.get(...)`
  calls).
- The same package's archived standalone README (pre-merge) demonstrates
  enforcement via `registerMiddleware(...)`, which current `alula`
  marks `@available(*, deprecated, ...)` in favor of `@Middleware` +
  `container.pipeline { }`.
- `alula`'s `AlulaWeb.docc`: references a `.stream { }` response
  constructor that doesn't exist in source — the real API is
  `.serverSentEvents(_:)` / `.streaming(contentType:)`.
- `alula`'s `AlulaActuator.docc` and top-level `README.md`: both
  describe `/actuator/info`, `/actuator/beans`, `/actuator/routes`, and
  `/actuator/config` endpoints that were never implemented — only
  `/actuator/health` and `/actuator` exist. `ActuatorModule.swift`'s own
  doc comment also overstates prod behavior ("the routes are simply not
  registered") — `/actuator/health` is registered in every environment
  by design; only the full dashboard is dev-gated.

Everything else in `PLAN.md` §7's curriculum outline exists only as a
title + description in `site/src/lib/curriculum.ts` / `guides.ts` — the
site renders those as a labeled "coming soon" placeholder, not a 404 and
not faked content. That distinction is load-bearing: check a slug against
the manifest before assuming it's written.

**CI**, all passing on real GitHub Actions runs (not just locally):
- `site.yml` — content link-checking (`scripts/check-content-links.py`,
  modeled on alula-cli's `verify-tutorial.sh`) + site type-check + build,
  on every push/PR.
- `docs.yml` — DocC → GitHub Pages for alula/hangar/alula-data. **Run
  for real** (GitHub Pages enabled via the API, `gh workflow run`
  triggered) — and caught three real bugs across four attempts, none of
  which a local test could have: (1) the `swift:6.3.3` container image
  has no Python at all, so `generate-docs-index.py` failed with
  `python3: not found`; fixed with an `apt-get install -y python3`
  step. (2) The workflow only ever checked out the three *external*
  repos it clones for DocC generation (`repository:`/`path:` on every
  `actions/checkout@v4` call) — there was never a plain checkout of
  `fledge` itself, so `scripts/generate-docs-index.py` never
  existed in the workspace at all. Every DocC-generation step worked
  fine regardless (they only touch the three cloned repos), which is
  exactly why this stayed invisible until the one step that needed this
  repo's own `scripts/` actually ran. Fixed by adding an initial bare
  `actions/checkout@v4` before the three named ones. Also fixed in the
  same pass: the generated index page linked to `fledge.dev`, a
  domain that isn't configured (confirmed via the Pages API — no CNAME;
  the real URL is `alula-framework.github.io/fledge/`, and the
  actual SvelteKit site has no fixed production domain yet either) —
  now links to the GitHub repository instead of a guessed-at domain.
  (3) **The serious one, found by a user, not by this process**: the
  third attempt was declared successful after only checking HTTP status
  codes on the index and one target page. Every DocC page was actually
  rendering blank — the `--hosting-base-path` baked into DocC's output
  (`fledge/reference/alula/$target`) didn't match where the
  artifact is really served (`fledge/alula/$target`, no
  `/reference/`), so every JS/CSS asset the page's client-rendered shell
  needs 404'd and `<div id="app">` never filled in. The workflow's own
  "Smoke-check hosting base path" step existed specifically to catch
  this and didn't, because it only grepped for the base-path string
  appearing *somewhere* in the output — always true, since DocC bakes
  in whatever it's told regardless of whether that's correct. Fixed the
  three `--hosting-base-path` values and replaced the smoke-check with
  one that extracts the real baked-in `baseUrl` and confirms a matching
  directory actually exists in the artifact — tested directly against
  both the broken and fixed values before trusting it in CI. **Deployed
  and confirmed for real**: curled the live pages for all three repos
  and checked that the baked-in `baseUrl` matches the real served path,
  and that the actual JS asset it requests resolves with 200 — the
  thing that was actually broken, not a status code on the outer HTML
  document. `swift-changeset` was added as a fourth repo immediately
  after (see above) and hasn't had its own deployed run yet.

## M1, well underway — the runner and the server

Per `PLAN.md` §10, M1 is "Snippet tier + Hangar/Changeset curriculum" —
the runner pool and channel-streamed output. Both halves of PLAN §4's
architecture now exist and have been verified talking to each other for
real: `runner/` (the sandboxed workspace + supervisor) below, and
`server/` (the sessions/execution Alula app that leases from the pool
and streams output to the browser over Channels) in the section after
it. `site/` still isn't wired to any of this yet — nothing here is
reachable by a learner through the actual deployed site, only through
direct HTTP/WebSocket calls to `server`, which is what verification used.

**What exists**: `runner/workspace` (a plain SwiftPM package — one
dependency, Hangar `0.2.1` — whose `exercise` executable target is the
one file a session is ever allowed to write to,
`Sources/exercise/main.swift`), `runner/supervisor` (an Alula app — yes,
this project dogfoods the framework it teaches even here — exposing
`/lease`, `/write`, `/run` (SSE-streamed build/run output), `/reset`,
`/release`), and `runner/Dockerfile` + `runner/entrypoint.sh` packaging
both into the sandboxed image PLAN §5 describes.

**Verified, not assumed** — the full lease → write → run → reset →
release cycle, tested against: the raw compiled supervisor binary; a
plain `docker run` of the built image; and the fully hardened
configuration — `--read-only`, tmpfs-mounted `/workspace` and `/tmp`,
`no-new-privileges`, a `pids-limit`, a memory ceiling, and full network
isolation (`--network none`) for the build itself. Real `debugSQL`
output came back correctly through the whole stack every time
(`SELECT "id", "total" FROM "orders" WHERE ("total" > $1)` for a
learner-written `@Entity` snippet, to pick one).

**Ten real bugs found by actually running this, not by writing it
carefully** — every one would have been invisible to a code review, and
each is the kind of thing "the plan already specified this" cannot
substitute for checking:

1. **`swift`'s path was hardcoded to `/usr/bin/swift`**, which doesn't
   exist on a Swiftly-managed install (this dev machine's own toolchain
   lives elsewhere). Fixed by resolving it through `env` instead of a
   guessed absolute path.
2. **The wall-clock timeout didn't actually kill anything.** A learner
   snippet using `@Entity` + `while true {}` survived `Process.terminate()`
   (SIGTERM) — confirmed this wasn't a Foundation bug by trying a bare
   `kill -TERM` from the shell against the same PID, which *also* failed.
   Whatever installs this behavior (almost certainly something in
   Hangar's SwiftNIO dependency chain, though the exact mechanism wasn't
   chased further — a bare Swift program with no such dependencies
   terminated on SIGTERM immediately) doesn't matter for the fix: the
   supervisor now escalates to SIGKILL, which cannot be caught or
   ignored, after a short grace period. Without this, the single most
   important safety property of the whole runner — a hung or malicious
   snippet gets killed, not trusted to finish — silently did not hold.
3. **A root-owned `/tmp` lock file broke every build as the runtime
   user.** The image's workspace was originally built as root, before
   `USER runner`; SwiftPM's lock file under `/tmp` came out root-owned,
   and the actual runtime user got "invalid access" on every build.
   Fixed by fixing ownership *before* building, so the same user builds
   and runs throughout.
4. **A `.build` baked at image-build time is unusable if the container's
   first build after starting doesn't trust it** — verified directly:
   the first `swift build` inside a freshly started container from an
   image with a prebaked `.build` recompiled everything from scratch
   (896 tasks, ~60s) instead of the ~2s incremental rebuild one changed
   file should cost, almost certainly Docker's layer export/import
   normalizing timestamps in a way that breaks SwiftPM's staleness
   detection across that boundary. A *second* build, live within the
   same running container, was correctly fast. Fixed by having the
   supervisor run its own warm-up build at startup, before the HTTP
   server even starts listening — paid once per container lifetime
   (containers are recycled after many leases, not per session), never
   by a learner's own first request.
5. **The tmpfs mount's `uid=`/`gid=` didn't match the image's real
   user** — guessed 1000 (the common default); the image's `useradd`
   actually assigned 1001. Fixed by pinning an explicit, stable uid/gid
   in the Dockerfile (10001) rather than depending on an implementation
   detail of one base image's `useradd` defaults, so anything
   orchestrating this container has a fixed number to depend on.
6. **Docker's tmpfs mounts are `noexec` by default**, and SwiftPM
   compiles and executes a temporary manifest-evaluation binary under
   `/tmp` on every build — every build failed with "Permission denied"
   until `exec` was added to both tmpfs mount options.
7. **A read-only rootfs breaks SwiftPM/Clang's own caches**
   (`~/.swiftpm`, `~/.cache/org.swift.swiftpm`,
   `~/.cache/clang/ModuleCache`), which live under `/home/runner` by
   default — not just the workspace. Fixed by redirecting `HOME` into
   the already-writable workspace tmpfs rather than adding a second
   mount.
8. **A network-isolated runner cannot `git clone` its own dependencies**
   — removing the (unusable, per #4) prebaked `.build` entirely and
   relying on the runtime warm-up build to fetch Hangar/PostgresNIO/NIO
   from the network directly contradicts "no network egress" (PLAN §5).
   Fixed by baking dependency *source* into the image via
   `swift package resolve` (fetches `.build/checkouts`, compiles
   nothing — carries none of #4's path sensitivity) at image-build time,
   so the runtime warm-up build only ever needs to *compile*, never
   fetch.
9. **`--pids-limit 128`** (a reasonable bound against a learner's
   fork-bomb) **is too tight for `swift build`'s own parallelism** —
   the warm-up build hit `posix_spawn: Resource temporarily unavailable`
   compiling SwiftSyntax/BoringSSL. Raised to 512 for this pass; the
   real fix (not yet done) is capping `swift build`'s own `-j` inside
   the supervisor so resource needs stay predictable regardless of what
   limit is configured, rather than just raising the limit until a
   from-scratch build happens to fit.
10. **A 2GB memory ceiling OOM-killed the warm-up build** under `--cpus
   2.0` (less headroom than an unconstrained build gets from more
   parallelism finishing faster). Raised to 4GB. The warm-up genuinely
   took ~14 minutes under the full hardened resource profile — a real,
   one-time-per-container-lifetime cost, not something a learner
   session ever waits on, but worth knowing before assuming "read-only
   + tmpfs + tight limits" is free.

**Not yet done here**: `docker-compose.yml`'s `runner` entry originally
used `deploy: replicas: 4` on one service — wrong, caught while building
the server on top of it (see below), now four named `runner-1`..`runner-4`
services instead. That, and everything else in this section, has been
validated with `docker compose config` and directly with `docker
build`/`docker run` against one runner at a time, but **not yet brought
up as the full multi-runner `docker compose up` stack** — see the
server section's own "not yet done" for the composite gap this leaves.
A custom seccomp profile (PLAN §5 calls for "seccomp default profile,"
which Docker already applies without any extra configuration — a
*tighter*, purpose-built profile is a real hardening step still open)
and `swift build -j` capping (see #9) are the two concrete follow-ups
worth doing before trusting this at real learner-facing scale.

## M1 continued — the server

The sessions/execution half of PLAN §4: `server/` is an Alula app —
`SessionBroker` (an actor holding pure in-memory pool/lease state: which
runners are free, which session holds which lease, when it was last
touched), `RunnerClient` (an `AsyncHTTPClient`-based caller of one
runner's `/lease`/`/write`/`/run`/`/reset`/`/release`, including a
from-scratch SSE parser for `/run`'s streamed output — nothing in Alula
consumes an SSE stream, only produces one, so this had to be written
against `ServerSentEvent.encoded`'s wire format directly), `SessionService`
(composes the two and fans `/run`'s output out to a `session:<id>`
Channel topic via `ChannelBroadcaster`, resolved with
`context.resolve(ChannelBroadcaster.self)` exactly the way
`benchmark/alula-app`'s `IssueController` already does it), a
`SessionController` (`@Controller`, `/api/session`, `/api/session/write`,
`/api/session/run`, `/api/session/reset`), a `SessionChannel` (join gate
for `session:*` — rejects a socket unless the topic's session id is
currently live), and `SessionReaperService` (the idle-TTL/hard-cap
reaper PLAN §4 calls for, structured the same way
`AlulaPresenceModule`/`PresenceService` are: a `final class` module that
stashes the post-freeze container so its `Service` can resolve from it —
the shape any service-owning module needs, confirmed by reading that
real precedent rather than guessing at the `AlulaModule.service` seam).

**Verified end to end against a real runner container**, not just
compiled: created a session, wrote a real `@Entity`-bearing Hangar
snippet, joined `session:<id>` over the WebSocket channel socket, called
`/api/session/run`, and watched the actual build output and
`debugSQL` line arrive as channel pushes —
`SELECT "id", "total" FROM "orders" WHERE ("total" > $1)` for a
hand-written `Order.where { $0.total > 100 }` snippet, streamed live,
not polled. Also verified: reusing an existing session id is idempotent;
`/write`/`/run`/`/reset` without a session id is rejected (400); joining
a channel topic for an unknown session id is rejected
(`alula:error`/`forbidden`); a failed runner lease correctly returns
the claimed runner to the free pool rather than losing it
(`SessionBroker.unclaim`); and, with the idle timeout and reap interval
turned down to a few seconds for the test, the reaper actually expires
an idle session, releases its runner lease back to the supervisor,
pushes a `session_expired` event to a still-connected socket, and frees
the runner for a brand new session to claim immediately after.

**Two real findings from building this, not from writing it carefully —
the first has since been fixed, not just worked around:**

1. **PLAN §4's "anonymous id (cookie)" wasn't reachable at first.**
   `Cookie`/`Set-Cookie` support landed on alula's `main`
   (`8997a5a`, "Add cookie support") *after* the `v0.8.0` tag this
   package resolved against at the time — checked directly (`git log
   v0.8.0..HEAD` in the alula checkout, plus confirming that checkout
   had *other* uncommitted changes sitting in its working tree, which is
   exactly the "don't read a dependency's mid-edit working tree" trap
   the tutorial-content work below already learned once). Landed
   temporarily on an `X-Session-Id` header instead, then actually fixed
   rather than left as a workaround: cut `alula` `v0.9.0` at that
   commit, which surfaced two more things worth knowing before trusting
   a release —
   - `ALULA_STRICT_WARNINGS=1 swift build --enable-all-traits` (CI's own
     build step) had been broken on alula's `main` since **before**
     `v0.6.0`, silently, through three tagged releases (`v0.6.0`,
     `v0.7.0`, `v0.8.0`) that all shipped without it ever passing —
     `DiskUploadStore.create(_:)` discarded `createFile`'s result (a
     failure there would have left an upload recording offsets against a
     `.bin` file that was never created) and `FileByteSource.realPath(_:)`
     used a deprecated `String(cString:)` overload. Both fixed, the full
     970-test suite and the lean-consumer dependency check verified
     passing locally before tagging.
   - A separate, uncommitted change already sitting in that checkout's
     working tree (encoding each Channel broadcast frame once instead of
     once per subscriber — a real perf fix, not scope creep smuggled in)
     got swept into the same release at the user's direction, verified
     the same way.
   - Cutting the tag itself surfaced a **third**, pre-existing, still-open
     gap: three *other* CI jobs (`Build on macOS`, `Build documentation`,
     the advisory `Format` lint) have been failing independently since at
     least `v0.8.0` — confirmed by checking that release's own CI run,
     not assumed. None of the three touch anything this session changed;
     none were chased further, since "fix the cookie issue" didn't scope
     in a macOS build environment (unavailable here anyway) or alula's
     doc-generation pipeline. Flagged, not fixed.
   `server/Package.swift` now pins `from: "0.9.0"`, `SessionController`
   uses real `Set-Cookie`/`request.cookie(_:)`, and the full lease →
   write → run → reset cycle was re-verified end to end against a real
   runner with the actual cookie flow (confirmed the response carries
   `HttpOnly`/`SameSite=Lax`, and that write/run/reset all work reading
   only from the cookie jar, no header).
2. **A replicated Compose service can't be leased into.** The `runner`
   entry in `docker-compose.yml` used `deploy: replicas: 4` on one
   service — which round-robins one shared hostname across containers
   via Docker's embedded DNS, so there's no stable name to pin a
   session's lease to one specific container for the session's whole
   lifetime. The Caddyfile already assumed named `runner-1`/`runner-2`/…
   services for exactly this reason (its own `/preview/N/*` comment, from
   before the runner even existed) — the compose file just hadn't been
   brought in line with it yet. Fixed with four named services sharing
   one hardening block via a YAML anchor, confirmed by inspecting
   `docker compose config`'s resolved output, not just eyeballing the
   YAML merge syntax.

**Also caught while wiring Caddy's `/api/*` and `/socket` routes**: a
`handle_path /api/*` block strips the matched prefix before proxying,
which would have forwarded `/api/session/write` to the server as
`/session/write` — a 404, since the server's routes are literally
`/api/session*`. Caught by running `caddy adapt` against the real
Caddyfile and reading the emitted route JSON (`strip_path_prefix` was
right there), not by assuming `handle_path` behaves like `handle`.
Fixed by using plain `handle` for both new blocks; the same `caddy
adapt` output also confirmed both new routes land ahead of the
catch-all `reverse_proxy site:3000` in Caddy's evaluated route order,
which was the other thing worth not just assuming from file order alone.

**Not yet done**: the full stack — `caddy` + `site` + `server` + all
four named runners — has never been brought up together via one `docker
compose up`; verification here used a single `docker run` runner
container and `swift run Server` on the host, pointed at it directly.
Also open: a `server` restart drops `SessionBroker`'s in-memory lease
map, but a runner's own lease state survives independently (its
supervisor still thinks it's leased) — so a server crash or redeploy
while sessions are live orphans those runners until something resets or
restarts them, since nothing reconciles "who does the runner think holds
it" against a fresh broker's empty state. Acceptable for v1's "sessions
are disposable" posture, but a real gap, not a hidden one. Neither
`runner/` nor `server/` has a CI build/test step yet (`.github/workflows/`
still only has `docs.yml` and `site.yml`) — everything above was verified
by hand, the same way the runner's own hardening was.

## M1 continued — the site UI is wired to the runner, for one exercise

The embedded editor exists now, not just the backend it talks to.
`site/src/lib/components/SnippetEditor.svelte` (CodeMirror 6 —
`basicSetup` + `StreamLanguage.define(swift)` from
`@codemirror/legacy-modes/mode/swift`, exactly the "community Swift
legacy-mode" PLAN §4 names) mounts on any `runtime: snippet` exercise
page that has starting content, creates/reuses a session on mount,
joins its `session:<id>` channel, and wires Run (write → run, output
streamed live into a pane) and Reset. `site/src/lib/client/session.ts`
is the whole client-side protocol: three `fetch` calls plus one
`WebSocket` join, all same-origin relative paths (`/api/...`,
`/socket`) — Caddy proxies both to `server` in production, and a new
`vite.config.ts` dev proxy (`SERVER_ORIGIN`, default
`http://localhost:9100`) does the same for `npm run dev` standalone.

**Wired and verified end to end for `02-data/03-predicates`** (the
`debugSQL` exercise — PLAN's own words call this "the pedagogical
jackpot of the snippet tier," so it was the obvious first one to prove
the whole path with) **and `02-data/01-entities`**: real runner, real
server, `npm run dev` with the proxy, and a Node script driving the
exact same fetch/WebSocket calls the component makes — through the vite
proxy on the site's own port, not directly against `server` — confirmed
the SSR'd page carries the article and the starting snippet correctly,
`svelte-check`/`npm run build` both pass clean, and the full
session → write → run → channel-push loop returns the real compiler
output and the real `debugSQL`/`print` line, live.

**One real content bug caught by actually running the exercise, not by
reading it**: `03-predicates.md`'s shown output wrapped `debugSQL`'s
single line across three lines for readability in prose — but the
learner's own editor, running the real snippet, prints one line, not
three. Fixed the article to show the real (unwrapped) line and added a
one-line callout explaining the wrap, rather than leave a first-run
learner wondering if their output is wrong when it's actually the
article that was formatted differently from reality.

**`02-data/02-first-queries` — redesigned, not left prose-only.** Its
literal example (`try await repo.all(query)`) needs a live `Repo`
against Postgres, which the snippet tier doesn't have. Rather than skip
it (the original call here, and wrong — see the M1-closing pass below),
the exercise now demonstrates the same point (composing from a shared
`base` never mutates it, and nothing executes until something asks) by
rendering two composed queries' `debugSQL` side by side instead of
executing either — arguably a *stronger* demonstration of "building a
query touches no database," since there's no database in this container
at all and the proof is right there in the output. Wired and verified
the same way as the others.

## M1 closed: audited the whole no-DB Part 2 curriculum, not just wired it

The user asked directly whether M1 was actually done before moving to
M2. It wasn't — `02-first-queries` was skipped rather than solved, and
a real gap existed in `04-changesets`. Checking that claim (not
restating it) is what surfaced three more real bugs, on top of the
`debugSQL`-wrapping one already found:

- **The "`04-changesets` needs a new runner dependency" note above was
  wrong.** Checked directly against Hangar `v0.2.1` (the exact tag the
  runner's workspace already pins): `Hangar`'s own `Package.swift`
  depends on `swift-changeset`'s `Changesets` product, `Hangar`'s
  `Exports.swift` re-exports it (`@_exported import Changesets`), and
  `@Entity`'s macro expansion already generates the `TableModel`
  conformance (`Changesets.TableColumn` catalog) every `Changeset` needs.
  `import Hangar` alone is the whole dependency — nothing to add,
  nothing to rebuild. The earlier claim was never checked against
  Hangar's actual source before being written down.
- **`@BelongsTo(foreignKey: \.fieldName)` — the shorthand keypath form
  shown in four places (`05-associations.md` ×2,
  `hangar-getting-started.md`, `hangar-preloading.md`) — does not
  compile.** Verified directly: `error: cannot infer key path type from
  context; consider explicitly specifying a root type`. Hangar's own
  test suite (`TestEntities.swift`) always writes the explicit form,
  `\Post.authorID`; fixed all four to match, then re-verified the
  corrected form actually compiles and runs (the thrown
  `HangarError.notPreloaded` prints "Association \"author\" was not
  preloaded. Add `.preload(\.author)` to the query that fetched this
  model." — also confirmed, not assumed).
- **Two guide code blocks referenced struct fields that were never
  declared** (`hangar-getting-started.md`'s `Post` used `authorID` and
  `published` without either being a stored property; a later example
  in the same file used `createdAt`, matching nothing) — a learner
  pasting the shown struct and then the shown query would hit "value of
  type 'Post.Columns' has no member." Fixed by declaring the fields the
  examples already assumed.
- **`hangar-getting-started.md` claimed `LIMIT` is parameterized**
  (`LIMIT $2`). Verified directly: it renders as a literal integer
  (`LIMIT 20`), not a bind placeholder — consistent with `LIMIT`/`OFFSET`
  needing no injection protection since they're never user-supplied
  strings. Fixed, and reused the exact confirmed output string across
  `hangar-getting-started.md` and `hangar-queries.md`, which share the
  identical query.

All five of Part 2's no-DB exercises are now wired and independently
verified against a real runner: `01-entities`, `02-first-queries`,
`03-predicates`, `04-changesets`, `05-associations`. Per PLAN §10, that
— plus the runner pool and channel-streamed output, both already
verified above — is what M1 actually asks for. `06-preloading` onward
correctly stays out of scope: preloading's own teaching point is a
measured N+1 ratio against real rows, which needs the `db` tier (M2).

**Not independently verified — flagged, not silently assumed working**:
no real browser was available to test this in (no Playwright, no
Chromium, no display) — verification here is SSR output, a production
build, type-checking, and driving the exact network calls the component
makes from a script standing in for a browser. CodeMirror actually
mounting without console errors, the Run/Reset button click handlers,
and the output pane's live-updating DOM have not been seen rendered.
Whoever next has an actual browser available should open
`/tutorial/02-data/03-predicates` and click Run before trusting this
further.

## M2, starting: migrated Part 2's no-DB content to the shared domain first

Before any M2 infrastructure, a real fork surfaced and got resolved: PLAN
§4 calls for one domain (issues/projects/users, reused from the benchmark
suite) across the tutorial, benchmark, and capstone — "the capstone can
never silently rot" depends on this — but the five already-wired,
already-verified Part 2 exercises (`01-entities` through `05-associations`)
used a different, unrelated domain (`Post`/`Author`/`Comment`) that
predates this session's work. Asked the user directly rather than picking
silently; the answer was to migrate now, before more DB-tier content gets
built on the wrong domain and the cost only grows.

All five exercises' articles and starting `.swift` snippets, plus the four
Hangar guides that shared examples with them
(`hangar-getting-started.md`, `hangar-queries.md`, `hangar-preloading.md`,
`hangar-changesets.md`), were rewritten against `Issue`/`Project`/`User`
(matching `benchmark/harness/schema.sql`'s real column names exactly —
`project_id`, `reporter_id`, `assignee_id`, `updated_at` — so M2's actual
seed schema, not yet built, will already match what these articles show)
and **every debugSQL/compile claim was re-verified against a real runner,
not translated by find-and-replace and trusted**. That re-verification
caught that the migration was a net *improvement*, not just a reskin:
`Issue.assigneeID` is a genuinely nullable foreign key in the real schema,
so the "nullable FK is a nullable `Loadable`" lesson in `05-associations`
and `hangar-preloading.md` now demonstrates a real column instead of an
invented `editorID` that only ever existed to illustrate the point.

`site/`'s type-check, production build, and `scripts/check-content-links.py`
all pass clean against the migrated content.

**Left deliberately unmigrated, not overlooked**: `06-preloading` through
`12-diagnostics` and `03-intermediate/01-repo-wiring` still reference
`Post`/`Comment`/`Author` — these are real, substantively-authored prose
(50–66 lines each) from before this session, not stubs. Migrating them
blind (text-only, unverified) would repeat exactly the mistake this
session's whole discipline exists to avoid — a "translated" example is a
claim, not a fact, until something actually runs it. Each will be migrated
as part of building and wiring it during M2, the same one-exercise-at-a-time
verification discipline used for Part 2's no-DB half. `Post` also appears
incidentally in three Part 1 materials (`01-basics/03-parameters.md`,
`01-basics/05-responses.md`, and two guides) as a generic "a route handler
returns a model" example, unconnected to the Hangar/Changeset curriculum
this decision was actually about — left alone; revisit only if full
site-wide domain consistency is ever explicitly wanted.

## M2 continued: the Postgres sidecar, seeded and verified

`postgres/schema.sql` and `postgres/seed.sql` are literal copies of
`benchmark/harness/{schema,seed}.sql` (not a package/submodule dependency
— it's SQL, not versioned code; re-copy both together and re-verify
`content/`'s debugSQL claims if the benchmark schema ever changes). A new
`postgres` service in `docker-compose.yml` loads them via the official
image's `docker-entrypoint-initdb.d` convention into a database named
`fledge_seed`, on `runner-internal` only (no `ports:`/`expose:` —
only `server` and the runners will ever need to reach it).

**Verified against a real container, not assumed from the compose
syntax being valid**: built the exact image with the exact schema/seed
mounts `docker-compose.yml` uses, confirmed the init scripts actually ran
(`INSERT 0 30` / `INSERT 0 1` / `INSERT 0 200`, matching the seed's own
claim), queried real distributions (30 users, 200 issues, 40 with a
`NULL assignee_id` — the real nullable-FK case `05-associations` and
`hangar-preloading.md` now teach against), and — the actual mechanism
M2's session provisioning depends on — confirmed `CREATE DATABASE s_test1
TEMPLATE fledge_seed` clones instantly with all 200 rows, a
`DELETE` inside the clone doesn't touch the template (confirmed the
template still has its row afterward), and `DROP DATABASE` cleans up
completely. `docker compose config` also validates the full service
definition.

**Not yet built**: the part that actually calls `CREATE`/`DROP DATABASE`
per session. That's `server`'s job — `SessionBroker`/`SessionService`
need a `db`-tier lease path that provisions `s_<sessionID>` on session
start and drops it on release/reap, and the runner's supervisor needs a
way to receive that session's connection string and make it reachable
from the learner's own snippet (an environment variable, most likely, or
a generated prelude file alongside `main.swift`) — neither exists yet.
Also not yet decided: what role/credentials the runner's own connection
to its session database uses (the shared `postgres` superuser is the
simplest thing that works and is what's verified above; PLAN §4's
"connection limits per session role" is real hardening worth doing before
this is learner-facing, not a v1 blocker — `ALTER DATABASE ... CONNECTION
LIMIT n` at creation time is the cheap first step, no separate role
needed). `06-preloading` — the first exercise that actually needs the
`db` tier — is the natural first target to wire once provisioning exists,
migrated to `Issue`/`Project`/`User` as part of that work per the section
above.

## M2 continued: per-session databases, real end to end, `06-preloading` wired

The gap the section above left open is closed. `server` now provisions a
real Postgres database for **every** session at creation, unconditionally
— not just `db`-tier ones. PLAN §4 only ever says "each session gets"
one, and once that's true there's no need for the server to track which
exercise a session is currently on (it doesn't, today) just to decide
whether to provision — `CREATE DATABASE ... TEMPLATE` is cheap enough
(re-confirmed below) that always provisioning is simpler than that
bookkeeping for a savings that was never shown to matter.

**The plumbing, end to end**: `server`'s new `PostgresAdmin` (backed by a
`PostgresNIO.PostgresClient` connected to Postgres's own always-present
`postgres` maintenance database, never the template) does
`CREATE DATABASE s_<sessionID> TEMPLATE fledge_seed` in
`SessionService.getOrCreateSession`, before the runner is even leased.
The resulting connection string travels to the runner over a new
`X-Database-Url` header on `/lease` (a header, not a JSON body, so
`/lease` keeps working with no body at all for a session — which is all
of them, now — since there's no per-database body to encode); the
supervisor's `WorkspaceState` remembers it for the lease's whole
lifetime, and `ProcessRunner` sets it as `DATABASE_URL` in the
environment of the *run* step only, never the build step (the build
needs no Postgres reachability — dependencies are already resolved into
the image). A new, never-overwritten `Environment.swift` in the
workspace template turns that into one line any exercise can use:
`let repo = try await makeRepo()` — parsing the URL, starting
`PostgresClient`'s background task, and handing back a ready `Repo`, so
individual exercises never repeat that boilerplate. The database is
dropped on both explicit release and idle/hard-cap reap
(`SessionReaperService`), mirroring exactly how the runner lease itself
is already released.

**Two real bugs, both found by actually booting the server, not by
reading the code back**:

- `PostgresModule.configure(_:)`'s first draft called
  `container.resolve(Configuration.self)` directly in the body of
  `configure` — this traps immediately
  (`Swift runtime failure: precondition failure`,
  `Container.resolveAny`: "resolve() called during the registration
  phase — resolution begins at freeze()"). `SessionBroker`'s existing
  registration already does this correctly (resolves *inside* its
  factory closure, which runs later, at `freeze()`); the fix was making
  `PostgresClient`/`PostgresAdmin`'s registrations follow that same
  shape instead of resolving eagerly.
- Then `PostgresModule.service`'s getter hit the identical trap a second
  way: `container.resolve(PostgresClient.self)` called directly in the
  getter, which runs in the *same* pre-freeze pass as `configure()` —
  confirmed directly by the crash trace pointing at
  `_alulaAssemble`'s per-module loop, before its later `freeze()` call.
  `AlulaPresenceModule`'s `PresenceService` and this app's own
  `SessionReaperService` both already avoid this by storing the
  `Container` and resolving lazily *inside* `run()` (called much later,
  once the app's `ServiceGroup` actually starts services) — the fix was
  making `PostgresClientService` follow that identical, already-proven
  shape instead of resolving in the getter.

**Verified against three real containers on one Docker network (postgres
+ one runner + server), not assumed from either fix compiling**:
creating a session produces a real `s_<sessionid>` database, confirmed by
listing databases directly against the container; `06-preloading`'s real
starting snippet (`makeRepo()`, `Issue.where { $0.status == "open"
}.preload(\.reporter).preload(\.assignee)`) built and ran for real,
returning genuine seeded data including a correctly-nullable
`assignee: unassigned` row; the nested-preload example from the same
article (`Project.preload(\.issues) { $0.order {
}.preload(\.reporter) }`) also ran for real, returning 3 ordered issues
each with their own preloaded reporter. `DROP DATABASE IF EXISTS`
confirmed directly via `psql` (the full reap-triggers-drop *code path*
wasn't separately re-run live — restarting the one test runner to clear
a stale lease from an earlier test cost another ~14-minute warm-up, and
the reap path reuses the exact same, already-verified
`dropSessionDatabase` method `endSession` already proved works — a
narrower but still real gap in what got exercised, noted rather than
quietly assumed covered).

**One real bug caught in the new exercise content itself, the same way
as always** — write it, run it for real, fix what breaks: the first
draft of `06-preloading.swift`'s `Issue` entity forgot to declare
`status` at all while the query filtered on it — a real compile error
(`value of type 'Issue.Columns' has no member 'status'`), fixed by
actually adding the field, not by reasoning that it should have compiled.

**Not yet done, honestly**: `PLAN §4`'s "connection limits per session
role" — every session's `Repo` connects as the shared `postgres`
superuser; a real hardening step before this is learner-facing, not a
v1 blocker (`ALTER DATABASE ... CONNECTION LIMIT n` at creation time is
the cheap first step, no separate role needed). A server restart still
orphans in-flight resources — previously documented for runner leases,
now also true for session databases (hit this directly mid-session:
restarting the server for a config change left an `s_...` database
nothing would ever have dropped, since the fresh broker instance never
learned that session existed; cleaned up by hand). `07-joins` onward
still reference the old `Post`/`Comment`/`Author` domain and are still
prose-only — `06-preloading` is the first, not the last, `db`-tier
exercise to migrate and wire.

## M2 closed: the remaining six `db`-tier exercises, migrated and wired

`07-joins` through `12-diagnostics` are migrated to the shared
issues/projects/users domain and wired to the `db` tier — `06-preloading`'s
pattern (migrate, write a real starting snippet, verify against real
runner+server+Postgres, fix what breaks) repeated six more times.
`11-alula-data` needed no domain migration at all — its code blocks were
already generic (`users`/`PricingService`/`Price`), not tied to the old
`Post`/`Comment`/`Author` domain, and it stays prose-only by nature (what
`alula-data` builds on top of Hangar, not a snippet to run).

**Four real things found only by actually running the snippets, not by
reading them back:**

- **Top-level script code is `MainActor`-isolated by default under Swift
  6.** `08-transactions.swift`'s first draft wrote `repo.transaction { tx
  in ... tx.transaction { inner in ... } }` directly at the top level and
  hit a real compile error on the *inner* call only: "sending value of
  non-Sendable type '(Repo) async throws -> Project' risks causing data
  races." `Repo.transaction`'s `body` parameter isn't `@Sendable`-typed at
  all (confirmed by reading `Transaction.swift` directly) — it relies on
  Swift's region-based "sending" analysis instead, which refuses to send a
  closure that closes over top-level (implicitly main-actor-isolated)
  state into a nonisolated async call. The fix: move the transactional
  logic into a plain top-level `func`, not top-level executable
  statements — a function *declaration* doesn't inherit the implicit
  main-actor isolation that top-level *code* gets, only the code that
  actually runs at the top level does. `12-diagnostics.swift`'s
  `detectingRepeatedQueries { }` call needed the identical fix for the
  identical reason (`body: () async throws -> T`, also not `@Sendable`).
  `09-multi.swift`'s closures never hit this, because `Multi.insert`'s
  dependent-step closures actually are declared `@Sendable` in the real
  API — a `@Sendable`-typed closure over plain value types is fine
  regardless of the caller's own isolation domain; it's specifically the
  *non*-`@Sendable`, "sending"-inferred parameters that break at the top
  level.
- **`repo.one(query)` always applies its own internal `.limit(2)`,
  ignoring any limit the query already carries.** `08-transactions.swift`
  and `12-diagnostics.swift` both first tried `repo.one(Issue.where {
  ... }.limit(1))` to grab "any one" row and both crashed at runtime with
  `one(...) on "issues" matched more than one row` — confirmed by reading
  `Repo.one` directly: it renders `query.limit(2)` unconditionally,
  specifically to *detect* an ambiguous predicate rather than silently
  picking a first row, so a caller's own `.limit` is simply overwritten.
  `.one()` is for a predicate that's supposed to be unique (a primary key,
  a `UNIQUE` column); "give me any one match, I don't care which" is
  `repo.all(query.limit(1)).first`, a different call, not a smaller limit
  on the same one. Both exercises' `.md` prose and `.swift` snippets were
  fixed to use the right one for each case (`repo.one` stayed correct
  everywhere the predicate is actually unique — `key == "BENCH"`, primary
  key lookups, the `(project_id, number)` uniqueness on the just-inserted
  issue).
- **`makeRepo()` built its `Repo` with `logger: nil`**, which made
  `12-diagnostics.swift`'s whole second half silently do nothing visible:
  25 real one-row-at-a-time queries ran (confirmed by the printed output),
  the repeated-query counter genuinely counted them, but
  `RepeatedQueryCounter`'s warning is emitted via `logger?.warning(...)` —
  a no-op against a `nil` logger. Fixed at the source rather than papered
  over in one exercise: `runner/workspace/Package.swift` gained a
  `swift-log` dependency, and `Environment.swift`'s `makeRepo()` now
  passes `Repo(client: client, logger: Logger(label: "exercise"))`.
  Harmless for every other exercise — swift-log's default level is
  `.info`, so this stays silent unless something actually sets
  `repo.diagnostics` or Hangar itself logs a warning/error — and it's what
  makes the exercise's own point actually observable: rerunning after the
  fix produced a real `[Hangar] hangar repeated query` line naming the
  exact SQL, the count (25), and the fix, in the run output a learner
  actually sees.
- **Restarting the runner container to clear a stuck lease desyncs it
  from the server's own bookkeeping.** Verifying six exercises in
  sequence against one runner (the test topology's single-runner pool)
  meant repeatedly needing a way to force a session's lease free between
  attempts. Restarting `test-runner-1` clears its in-memory
  `WorkspaceState` (and is fast — ~5s, since the image's `.build` is
  already warm), but the *server* doesn't know that happened: its
  `SessionReaperService` later tries to `/release` using the *old*
  session's *old* lease id against a runner that's since handed out a
  new one, and gets a 403. Confirmed directly in `test-server`'s own
  logs (`failed to release runner ... runner returned 403 for
  /release`) — a variant of the already-documented "server restart
  orphans runner leases" gap, this time triggered from the runner side
  instead. Not fixed (it's a test-harness workaround causing test-harness
  fallout, not a product bug); the safer alternative when it matters is
  waiting out the idle-timeout reaper instead of restarting the runner
  underneath it.

**Verified for real, one session per exercise, against the same
three-container topology as `06-preloading`** (`postgres` + one runner +
`server`, single-runner pool config since only one runner container
exists in test topology): `07-joins`'s three-table join
(`Issue.join(Project.self,...).join(User.self,...)`) returned real joined
rows; `08-transactions`'s nested transaction/savepoint inserted a new
issue *and* advanced `project.nextIssueNumber` inside one outer
transaction; `09-multi`'s dependent-step `Multi` created a new project
and a first issue whose `reporterID` depended on the just-inserted
project's owner, in one call; `10-bulk-writes`'s insert/update/delete
trio ran against a dedicated, self-contained project (never touching the
shared `BENCH` seed data) and returned real row counts (3 inserted, 3
closed, 3 purged); `12-diagnostics`'s `EXPLAIN ANALYZE` returned a real
Postgres plan (`Seq Scan on issues ... Rows Removed by Filter: 194`) and,
after the logger fix, its repeated-query detector fired for real on a
genuine one-parent-at-a-time reporter lookup.

## M3 reversed: the app tier was built, measured, and then dropped

The `app`/`app+db` execution tiers were built end to end and then removed
on purpose. What follows is the reasoning, because the code is gone from
`main` and only the git history explains it otherwise.

**What was built and did work**: a persistent-process runner lifecycle
(build, spawn a server, keep it alive across the lease), multi-file writes
with a structural allowlist, a `preview` Docker network, Caddy
`/preview/runner-N/*` routes, tier-aware sessions with a `previewPath`,
and a tabbed editor with a live preview iframe. Seven Part 1 exercises
were wired and verified through the whole chain. None of it was removed
for being broken.

**Why it went anyway** — the costs are concrete and were all measured
here, not estimated:

- **~25 minutes of warm-up per container start**, rising to ~35 with the
  third template `app+db` needed. Two warm `.build` trees already took
  2.1G of a 4G tmpfs. That is a deployment cost *and* a tax on every
  iteration of the work itself.
- **A pool that must stay warm**: four runners at an 8G ceiling, on a VM,
  around the clock, for a site most visitors will read rather than run.
  PLAN §5 already concedes it is "a small free compute faucet."
- **The lessons kept not fitting the tier.** Three Part 1 exercises had to
  be retargeted off a database the `skeleton` template doesn't have.
  `08-middleware`'s payoff was invisible until it was redesigned around a
  response header, because app logs don't stream anywhere.
  `09-configuration` can only be half-taught while `alula.yaml` stays
  unwritable — and it has to stay unwritable, since it carries the host
  binding the preview depends on. `07-static-assets` was blocked outright
  by prefix-stripping, which needs per-runner hostnames to fix.
- **The payoff was thinnest exactly where the cost was highest.** Part 1's
  interactive value is watching "hello, alula" appear in an iframe;
  `alula new` gets a learner there in two minutes on their own machine.

Contrast the snippet/db tier, which stays: one file, ~1.8s rebuilds, no
proxy, no ports, no HTML — and `debugSQL` printing real SQL beside the
Swift that produced it is something a static code block genuinely cannot
do. That tier earns its keep; the app tier didn't.

The economics differ from the obvious comparison, too: Svelte's tutorial
runs in the browser at zero marginal cost per visitor. Ours needed a warm
VM. Same idea, completely different bill.

**What was kept from the work**:

- **Part 1's content**, in PLAN §6's directory shape (`README.md` +
  `meta.json` + `app-a`/`app-b`), rendering as prose. The solutions in
  `app-b` are real and were compiled and curled, and they stay so CI can
  materialise template + diff and build them.
- **The bug-catching, which is where the value actually was.** Running the
  content caught a `ResponseEncodable` error that had been wrong in
  published prose since M0, an invisible-payoff exercise, and a genuine
  upstream bug in alula-cli's `basics` template (fixed there, `be90caa`).
  **None of that needed a live runner pool** — and it is now
  `scripts/check-exercises.py` plus `.github/workflows/exercises.yml`,
  which is PLAN §6's promise ("builds and runs every `app-b` solution, and
  executes every snippet solution") actually delivered.

  All 18 exercises pass: 11 snippets built *and run* against real seeded
  Postgres, 7 `app-b` solutions built against a real `alula new` template
  checked out from alula-cli rather than vendored, so the CLI stays the
  single source of truth for project shape.

  It was verified the only way a test suite can honestly be verified — by
  breaking things and watching it fail. Reintroducing the
  `ResponseEncodable` bug failed exactly `02-first-route` while the other
  six still passed, which also proves the between-exercise reset works
  (three exercises define `IssueController`, so a leftover file could
  otherwise satisfy a reference that should have failed). Reintroducing the
  `repo.one`-on-a-non-unique-predicate bug was the more interesting one:
  it **compiled cleanly** and failed only when run. That is the whole
  argument for running rather than building, demonstrated rather than
  asserted.

  Two real bugs were found in the suite itself while building it, both by
  running it rather than reading it: it copied a compiled `.build` into a
  temp directory, which cannot work because Clang bakes absolute
  module-cache paths into `.pcm` files — the same trap the runner's
  Dockerfile already documents — and the `swift:6.3.3` image has neither
  `python3` nor `rsync`, found by executing the workflow's steps in that
  image rather than assuming what it contains.

  Known limit, stated rather than left to be discovered: the run phase
  checks the **exit code**, not the output. A snippet that prints the wrong
  thing and exits 0 still passes. PLAN §6's "expected-output assertions"
  would close that; both bugs this has caught so far were a compile error
  and a crash, so neither needed it yet.
- The stale-build diagnostic and the `421` guard on `/api/*`, both of
  which came out of the same period and apply regardless of tier.

Parts 1, 3 and 4 finish as prose plus a project the learner runs locally —
which PLAN §1 already named as the degraded mode, and which turns out to
be the right *primary* mode for anything bigger than a snippet.

## Parts 3 and 4 verified — five more bugs in published prose

Every exercise in Parts 3 and 4 that carries user-written Swift now has an
`app-b` compiled against the real `alula-cli` template, so CI covers it.
This was the largest remaining risk: 16 exercises of the hardest material
— auth, uploads, SSE, scheduling, channels, presence, the capstone — whose
code had never once been through a compiler.

It found five things, all of which had shipped:

- **`principal.name` does not exist**, in *two* articles (`04-presence`,
  `08-capstone`). `ChannelPrincipal` has `subject` and `hasRole(_:)` and
  nothing else; the demo template uses `principal.subject` throughout.
- **`@Service final class` cannot compile** (`02-authentication`).
  `@Service`'s expansion requires `Sendable`, and a class holding a mutable
  `@Inject` property cannot be one. The error names `Sendable` at the
  macro rather than the property, which makes it read as stranger than it
  is. A `struct` is the shape the templates use everywhere.
- **`Channel` is ambiguous in the capstone.** `AlulaDataPostgres`
  transitively re-exports NIO, and `NIOCore.Channel` is a socket, not a
  topic — so a file importing both halves must write
  `AlulaChannels.Channel`. Nothing earlier hits this, because the capstone
  is the first exercise to combine realtime with data, which is its whole
  purpose. Its presence payload is also `[String: String]`, so wrapping a
  value in `.string(…)` is a type error.
- **`@Scheduler` needs `import Foundation`** (`05-scheduling`) — the
  expansion refers to `Date`, and omitting it fails inside macro-expanded
  code rather than at anything the reader typed.
- **A struct initialised with a property it doesn't declare**
  (`01-websockets`'s `EchoHandler(room:)`).

Every one is the same class of defect: plausible-looking code that no one
had run. Each is now fixed *and explained* in the article, since a reader
hitting the same wall deserves the reason rather than just the cure.

Where an article quotes a framework declaration rather than user code, the
check was different — compare it to the real source. `PresenceEntry`,
`PubSub`, `DistributedPubSubAdapter`, `onTopicTerminated`,
`heartbeatCheckInterval`, `heartbeatTimeout`, `gracefulShutdownSignals` and
`AlulaPubSubValkeyModule` all match what is printed. `05-teardown`,
`07-clustering`, `09-deployment` and `06-actuator` stay prose because that
is all they contain.

Templates are named per exercise, not per part: `basics` where the lesson
is only data, `demo` where it needs Security, Scheduler, Channels or
Presence traits `basics` doesn't carry. The checker also learned to pass
`--build-tests` when a solution lives in `Tests/`, which plain
`swift build` skips entirely — without it those files would have reported
a pass while never being compiled.

**19 `app-b` solutions and 11 snippets: 30 of 41 exercises now verified.**
The remainder are prose by nature (Part 0's four, `06-actuator`,
`11-alula-data`, and the three above) plus `07-static-assets` and the
still-unwritten `06-cookies`.

## 41 of 41 written; a framework bug found by the last one

`06-cookies` — the exercise deliberately left unwritten since M0 because
cookie support was unreleased — is written and verified. alula `v0.9.0`
carries it (`8997a5a`), and the templates' `from: "0.7.0"` resolves there,
so a reader's own `alula new` can reach it now. The article covers the
whole progressive-enhancement login loop: `Response.seeOther` for the
POST-redirect-GET, `settingCookie`, `request.cookie`, and clearing by
overwriting with `Max-Age=0`. Verified by running it — logging in returns
`303` with `Set-Cookie: who=Ada; Path=/; Max-Age=3600; HttpOnly;
SameSite=Lax`, the follow-up request reads it back, and logout clears it.

The defaults turned out to be the most interesting part to teach, so the
article covers them explicitly: `HttpOnly` and `SameSite=Lax` are on by
default, while `Secure` is deliberately *off* — a `Secure` cookie over
plain HTTP is silently never set, which looks exactly like broken login
logic on a loopback dev server.

`07-static-assets` stays prose for now, and the reason is a **real bug in
alula, found by trying to compile the article's own code**:
`container.pipeline("assets") { }` with an empty block did not declare the
lane, so the asset mount naming it failed at bootstrap — with an error
that itself says "an empty block is legal". `pipeline(_:_:)` registered
one entry per middleware, and `declaredMiddlewareLanes()` derives the lane
set from those entries, so an empty block registered nothing and the lane
left no trace. The empty lane is not a curiosity here: it is precisely
what an asset mount wants, so a request for `app.js` pays for none of the
auth and transaction binding the default lane carries.

Fixed upstream in alula (`bd300c4`): `pipeline(_:_:)` now registers a
marker per named lane, filtered out of `collectMiddleware(lane:)` so a
request through an empty lane still runs nothing. The first attempt broke
the existing two-modules-concatenate test — a fixed marker qualifier made
the second declaration a duplicate registration — which is why the marker
carries a per-call token. A regression test asserts the route serves and
the lane composes to an empty chain; it was confirmed to fail without the
fix, with exactly the original error. Full suite green at 970 tests.

alula `v0.9.1` was cut carrying that fix, and a fresh `alula new --tier
skeleton` resolves to it, so `07-static-assets` is now verified too —
with the empty lane the article actually teaches, not a workaround.

Everything the article claims was checked against the running app rather
than assumed: a real route still wins over the mount; the content-hashed
bundle gets `Cache-Control: public, max-age=31536000, immutable` while
`index.html` gets `no-cache` from the *same* mount; an HTML-preferring
miss gets the SPA shell while the same miss preferring JSON gets an
honest 404; `/api` stays excluded rather than falling into the shell; and
a conditional request carrying the ETag comes back `304` with a zero-byte
body. The article now also states the `0.9.1` floor, since an empty lane
silently failed to exist before it.

**Part 1 is complete: all nine exercises written and CI-verified.**

`curriculum.ts`'s runtime labels were also stale: Parts 1, 3 and 4 still
claimed the `app`/`app+db` tiers that were removed. They are now `local`
— real, CI-verified code the reader runs in their own project — and the
type no longer offers tiers nothing serves.

## Explicitly deviated from PLAN.md §6, on purpose

The plan's content layout has each exercise as a directory with
`README.md` + `meta.json` + `app-a/`/`app-b/` diffs against a CLI
template. What's actually here, even now that the snippet tier is
interactive, is flatter: one `.md` file per exercise with frontmatter
(`title`, `description`, `order`), plus — new as of the UI wiring above —
one sibling `.swift` file per *wired* snippet exercise holding its
starting code (`03-predicates.md` / `03-predicates.swift`). Not
`meta.json` + `app-a`/`app-b`: a `snippet`-tier exercise is one file with
no project structure around it, so a `meta.json` naming an "editable
file allowlist" and an `app-a` *directory* would be describing a project
that doesn't exist for this tier. `app-a`/`app-b`'s real shape — a
project-structured directory diffed against a `alula new` template —
still doesn't exist anywhere, because nothing has reached the `app`/
`app+db` tiers yet, where a learner actually edits files inside a
project. Revisit when that tier is built; don't assume the sibling-file
shape generalizes to it.

## Not started

- `server/`'s *content* module (PLAN §4: serving compiled exercise/guide
  JSON from a build-time manifest) — `site` still reads `content/`
  directly and per-request (`site/src/lib/server/content.ts`); nothing
  has forced that to change yet.
- "Solve" diffing, session presence, the preview proxy, and the
  `app`/`app+db` execution tiers (PLAN §3) — the `db` tier's own tutorial
  content (Part 2, `01-entities` through `12-diagnostics`) is now fully
  migrated and wired; `app`/`app+db` (a learner editing files in a full
  Alula application, not one snippet file) are a different, larger
  architecture problem, genuinely M3+, not something left unfinished here.
- `03-intermediate/01-repo-wiring` — still references the old
  `Post`/`Comment`/`Author` domain and isn't wired to the `db` tier;
  Part 2's `06-preloading` through `12-diagnostics` migration is the
  pattern to repeat for it: migrate the domain, write a real starting
  snippet, verify it against a real runner+server+postgres before
  trusting it.
- A similar accuracy pass over the *rest* of the plain-docs guides
  (`up-and-running.md`, `routing-and-controllers.md`, etc.) and the
  `db`/`app`-tier curriculum once those tiers exist — the M1-closing
  audit above only covered the Hangar/Changeset guides, since that's
  what M1's own scope touches. Worth doing again whenever a tier goes
  from written to interactive, on the same theory that caught these
  bugs: a code block nobody's run is a claim, not a fact.

## If you're picking this up cold

Read `PLAN.md` first, all of it — §7a and §8a in particular record two
corrections made *after* the original plan was written, each from
actually checking a claim against source rather than trusting the first
draft. The tutorial curriculum itself is now fully written (see above),
so the immediate next work here is more likely to be M1+ (the execution
tiers) than new tutorial content — but if a gap does turn up (a new
alula/Hangar/alula-data release unblocking `06-cookies`, a curriculum
correction, a new guide), the same pattern that got the rest of this
content right still applies: don't assume a config/CLI flag/API shape
without grepping the real source first — this plan has already been
wrong twice in ways that only source-checking caught, and the "real bugs
found upstream" list above has grown to seven instances since. Note that
`alula-cli` itself carries no tags at all (`git tag --list` is empty
there) — there's no release boundary to check its templates/`TUTORIAL.md`
against the way there is for `alula`/Hangar/`alula-data`; treat its
`main` as the only version that exists.

Parts 3 and 4's verification used parallel research agents, one per
independent subsystem, rather than one sequential pass through
everything — it worked well for both and is worth reaching for again any
time a body of work splits cleanly into independent pieces, whether
that's more tutorial content or something else entirely. An agent's
findings still got cross-checked before anything was written from them,
the same as any other source — one of Part 4's findings (testing)
directly corrected a claim already published in Part 0's
`04-running.md` about what `TestClient` actually is, which is the
reminder worth keeping: re-read earlier content in light of later
findings, don't just trust it because it already shipped.

Before trusting any upstream package as a source of truth, check it's
not mid-edit: `git status --short` in that package's own checkout, and if
anything's uncommitted, read the tagged release (`git show
<tag>:path/to/file`) instead of the working tree for whatever you're
about to cite. Two sibling repos (Hangar, swift-changeset) had real
in-progress uncommitted work while Part 2 was written; reading their
working trees directly would have pulled in unreleased API shapes a
learner's own dependency resolution can't reach yet (exactly the
`06-cookies` situation above, just easier to miss one repo over).

One content-pipeline gotcha worth knowing before it costs you a debugging
session: **content is parsed at *request* time, never at build time** —
`npm run build`/`npm run check` typecheck the site's own code but never
touch a `.md` file's frontmatter, so a YAML mistake there (an unquoted
string containing `:`, say — caught once already, in
`02-data/12-diagnostics.md`'s frontmatter, before it shipped) passes both
cleanly and only breaks when the page is actually requested. Spot-check
new content against a real running server (`node build/index.js` with
`CONTENT_ROOT` set), not just the build/typecheck/link-check trio.

**A status code is not proof of content, full stop — this was learned
twice in one session and is worth stating as a hard rule now rather than
trusting it'll stick after one example.** The first time (above) was the
production `CONTENT_ROOT` bug: a missing page and a broken content load
both return 200. The second time was worse, because it involved a *live*
deployment declared done on exactly this mistake: every DocC page on
GitHub Pages was rendering completely blank — a client-side SPA shell
whose JS 404'd because of a hosting-base-path mismatch — while the HTML
document itself still answered 200 the whole time. A user found it; the
verification pass that declared the DocC deploy "confirmed working" had
checked only `curl -o /dev/null -w "%{http_code}"` against the index and
one target page. The fix: when a page can render blank/wrong while still
returning 200 — anything with client-side rendering, a JS-populated
shell, or content loaded after the initial response — the check has to
look at what the page actually contains (grep the body for expected
text, or for a client-rendered page, check that its actual asset URLs
resolve), never the status code alone.
