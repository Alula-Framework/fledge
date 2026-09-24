# Fledge — interactive tutorial + documentation site

**Status: plan, not implementation.** Own repo under the Alula-Framework org.
Proposed name: `fledge` (alternatives: `alula-learn`, `learn-alula`).
The name matters less than reserving it before content links bake it in.

The ask: a docs/tutorial site for Alula in the mold of Svelte's
learn.svelte.dev — interactive, embedded editor, step-by-step descriptions —
covering setup → basics → intermediate → advanced, including Hangar and
Changeset, *plus* a parallel plain-documentation track written at the
expression/detail bar of the Phoenix and Ecto guides. Svelte 5 frontend,
Alula backend, easy to deploy.

---

## 1. Goals and non-goals

**Goals**

1. A learner can go from "never seen Alula" to a working realtime app
   entirely in the browser — no local toolchain — and at any point eject to
   a local project that matches what they built (`alula new` emits it).
2. Every interactive exercise has a narrative worth reading on its own: the
   site degrades to excellent static documentation when the execution
   backend is down, unfunded, or rate-limited.
3. Hangar and Changeset are first-class curricula, not appendices — the
   Ecto guides are the quality bar and Hangar's feature surface (entities,
   queries, preloading, changesets, Multi, transactions, bulk writes, soft
   delete, CTEs, diagnostics) maps almost one-to-one onto Ecto's guide
   topics.
4. The site itself is the best Alula demo in existence: the backend is
   Alula, build/run output streams over Alula Channels, the session
   presence indicator is Alula Presence. Dogfooding is a feature, not a
   flourish.
5. One-command deploy on one machine. Scale later, if ever.

**Non-goals (v1)**

- No in-browser Swift compilation (SwiftWasm compiles *to* wasm on a
  server; compiling Swift *in* the browser is not viable — see §3).
- No user accounts. Progress lives in `localStorage`; sessions are
  anonymous and ephemeral.
- No arbitrary-package playground. Only the curated workspace images run.
- No clustering tutorials against real multi-node deployments (single-node
  scope, same fairness reasoning as the benchmark suite; clustering gets
  prose + diagrams, not a live sandbox).

---

## 2. Prior art, and what we take from each

**learn.svelte.dev** (now svelte.dev/tutorial; repo public). The content
model to copy wholesale: sections → exercises; each exercise is a folder
with `README.md` (the narrative), `app-a/` (files the learner starts with),
`app-b/` (the solution). The UI: text left, editor + preview right, file
tree, "solve" button that diffs a→b. What we *cannot* copy: WebContainers.
Their runtime is Node-in-the-browser; Swift has no equivalent, so our
execution moves server-side (§3) and their per-keystroke feedback loop
becomes a Run-button loop with honest latency budgets.

**Rust Playground / Go Tour / SwiftFiddle.** The server-side execution
prior art: sandboxed containers, prebuilt dependency caches baked into the
image, strict CPU/memory/time/pids limits, no network egress. Rust
Playground's key trick — the crate cache is built into the image so user
code only ever compiles one file — is exactly our warm-workspace model, and
we have measured numbers proving it works for Swift (§3).

**Phoenix / Ecto guides (hexdocs).** The prose bar for the plain-docs
track: narrative guides that teach a concept end-to-end with runnable
snippets and honest "why," separate from per-symbol API reference. Ecto's
"Getting Started" and its changeset/preloading guides are the direct
models for the Hangar track. Alula/Hangar already have DocC catalogs for
API reference; the site links to statically-hosted DocC rather than
duplicating it (§8).

**alula-cli** (`alula new MyService --tier skeleton|basics|demo`,
`--with postgres,valkey,security`). Templates are embedded in the binary
and CI-tested. **Decision: the CLI templates are the single source of
truth for tutorial workspaces.** The tutorial's starting workspaces are
generated from the same tiers, so "eject to local" is literally
`alula new` plus the diffs the learner has made — and template drift
between CLI and tutorial becomes structurally impossible.

**The audit this section deferred has now been done, and it changes the
plan materially (see §7a).** `alula-cli/TUTORIAL.md` is not a stub — it
is a real, ~47KB, 8-stage-per-part tutorial (skeleton → persistence →
realtime, including auth, caching, and scheduled jobs), and it is
**CI-enforced today**, not aspirational: `CI/verify-tutorial.sh` greps
every `templates/…` path and every named type/function TUTORIAL.md
references and fails the build if either has drifted, specifically
*because* — its own comment says — "the previous tutorial in this
ecosystem drifted until seven of the nine files it told you to create no
longer existed. Nothing caught that, because prose does not compile."
That check, and the failure mode it responds to, is direct prior art for
Fledge's own content-CI (§6) and should be adopted as a first,
cheap gate ahead of the heavier build-and-run one already planned there.

**A second repo surfaced in the same audit: `alula-data`** — persistence
*and* caching, deliberately one package ("the abstractions and the
drivers live together because they break together"): `AlulaDataCore`/
`AlulaCacheCore` always resolve; `traits: ["Postgres"]` adds
`AlulaDataPostgres`, `AlulaMigrate`, `AlulaMigrateCLI` — **and pulls in
Hangar as a dependency of the Postgres driver itself.** Hangar is not a
freestanding alternative sitting beside alula-data in the curriculum;
alula-data's Postgres story is built on it. §7a corrects Part 2's framing
accordingly. `traits: ["Valkey"]` adds `AlulaCacheValkey`/
`AlulaDataValkey`. alula-data also ships its own `Docs/*.md` (one file
per driver — `cache.md`, `data-postgres.md`, `migrate.md`, …) and a
`Snippets/` convention, both directly reusable for the plain-docs track.

---

## 3. The central technical problem: running Swift interactively

This is where the deep thinking went, and it is measurement-backed, not
assumed. Probes run on the dev machine (Linux, Swift 6.3.3, Swiftly):

| Fact | Result | Consequence |
|---|---|---|
| `swift repl` headless on Linux | **works** (evaluated piped input; lldb ships in toolchain) | bare-REPL tier is real |
| `swift run --repl` on a macro-bearing package (Hangar) | **broken** — duplicate modulemap between host `-tool` and target builds | package-REPL is not the v1 path |
| Warm one-file rebuild in a prebuilt package (imports Hangar + PostgresNIO, `@Entity` macros expanding) | **1.81s measured** | snippet tier is comfortably interactive |
| Alula app warm incremental rebuild | **7–8s** (measured repeatedly across the benchmark sessions) | app tier is Run-button, not keystroke |
| Alula app debug clean build | ~73s | cold builds must never happen in a session |
| Alula app release clean build | ~470s (22 SwiftSyntax modules) | runner images bake `.build` at image-build time, debug config only |

**Decision: a tiered execution model, declared per exercise in metadata.**

- **`none`** — prose only. Renders always, costs nothing.
- **`snippet`** — the workhorse, and the whole Hangar/Changeset curriculum.
  The runner holds a warm SwiftPM workspace whose `.build` was baked into
  the image; the learner's editor content is written to
  `Sources/exercise/main.swift`; `swift build && run` completes in ~2s
  warm. Macros work (measured — `@Entity` expanded in the probe). Hangar
  is *ideal* for this tier because `debugSQL`/`renderedQuery()` produce
  the interesting output — rendered SQL and binds — with no database at
  all, and Changeset validation is pure computation.
- **`db`** — snippet + a session database. Postgres sidecar; each session
  gets `CREATE DATABASE s_<id> TEMPLATE fledge_seed` (~100ms),
  dropped on session end/TTL. This unlocks the second half of the Hangar
  curriculum: real inserts, preloading against real rows, transactions,
  `EXPLAIN`.
- **`app`** — the learner's edits are files in a full Alula application
  (a `alula new` tier); Run rebuilds (~7–8s) and restarts the app on the
  runner's assigned port; an iframe previews it through the proxy (§4).
  Routes, controllers, middleware, cookies, forms, static assets.
- **`app+db`** — the above plus the session database. Auth, uploads, and
  the capstone realtime board (channels + presence — the benchmark suite's
  `BoardChannel` arc is a ready-made curriculum, already conformance-tested
  from the outside by `ws-conformance.js`).

**REPL verdict** (the user asked directly): available and integrable for
*bare* Swift, but the package-import path is blocked today by the SwiftPM
duplicate-modulemap wart, and a REPL that can't `import Hangar` teaches
nothing we need. The 1.81s snippet tier makes the REPL unnecessary for v1.
Keep it as a stretch enhancement behind a clean seam: a "console" pane that
would speak to a pooled `swift repl` process with a curated
`-I/-L` invocation against prebuilt modules — to be attempted only after
verifying macro expansion inside lldb's REPL, which is a genuine open
question (§14). Nothing in the architecture depends on it.

**Latency honesty in the UI.** Svelte's tutorial feels instant; ours will
not, and pretending otherwise reads as broken. The Run button shows the
live compiler pipeline (streamed over a channel — §4), so 2s feels like
work happening and 8s feels like a real app assembling, not a hang. Cache
the last output; show diffs of output when re-running.

---

## 4. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Caddy (TLS, static assets, routing)                         │
│   /            → site (SvelteKit, adapter-static or node)   │
│   /api, /ws    → server (Alula)                            │
│   /preview/N/* → runner-N (fixed pool → static routes,      │
│                  WebSocket pass-through included)           │
└─────────────────────────────────────────────────────────────┘
   site/      Svelte 5 frontend: docs + tutorial UI
   server/    Alula app: content API, session broker, channels
   runner-N/  N identical sandboxed workers (compose scale)
   postgres/  one server: site DB (sessions) + template DBs
   content/   exercises + guides (markdown + workspace files)
```

**Frontend (`site/`, Svelte 5 + SvelteKit).** Runes throughout; this is
also implicitly a Svelte 5 showcase given the Aluladeck prior art. Editor:
**CodeMirror 6** (what learn.svelte.dev uses; Monaco is heavier and worse
on mobile) with the community Swift legacy-mode for highlighting —
lightweight, no LSP in v1 (an LSP-over-websocket to sourcekit-lsp on the
runner is a stretch goal; it's a real memory cost per session and the
tutorial pedagogy doesn't need completions). Layout mirrors the Svelte
tutorial: narrative left; tabs right for Editor / Output / Preview;
file-tree when the exercise has multiple files; **Solve** toggles a→b with
a diff view. Progress in `localStorage`. The plain-docs pages are the same
SvelteKit app rendering `content/guides/*.md` — one deploy, one design
system.

**Backend (`server/`, Alula).** Modules: content (serves compiled exercise
+ guide JSON; content is compiled to a manifest at build time, not parsed
per request), sessions (lease a runner from the pool, mint session id,
TTL reaper), execution (forwards run requests to the leased runner,
**streams stdout/stderr/compiler diagnostics back over an Alula Channel**
— topic `session:<id>`, events `build_output`, `build_done`, `run_output`,
`exited`), presence on the exercise topic ("N people on this exercise
right now" — tasteful, optional, pure dogfood). The browser talks to it
with the same envelope protocol the benchmark suite already speaks and
tests.

**Runner (`runner/`).** A container image containing: Swift toolchain, the
prebuilt workspaces (one per execution tier/template, `.build` warm, built
in CI at image-build time), a tiny supervisor (can be Swift) exposing an
internal HTTP API: `POST /lease`, `POST /write` (file contents),
`POST /run`, `GET /stream`, `POST /reset`, `POST /release`. **Pool model,
not spawn-per-session:** compose runs N identical runners; the server
leases one per session; on release/TTL the supervisor scrubs (kill
processes, reset workspace from pristine copy, drop session DB) and
returns to pool. Fixed pool ⇒ the preview proxy is static Caddy config
(`/preview/3/* → runner-3:9003`) — boring, and WebSockets just work, which
the channels exercises require. Spawn-per-session (stronger isolation,
docker-socket exposure, dynamic proxying) is deliberately deferred to a
hardening milestone; the scrub-and-recycle trade-off is acceptable at v1's
trust level because of §5.

**Session lifecycle.** Anonymous id (cookie) → lease on first Run (not on
page load — most visitors read) → idle TTL ~10min, hard cap ~60min →
scrub. Pool exhausted → honest queue UI + "run locally" instructions
(every exercise is downloadable as a SwiftPM package; that is also the
degraded mode and the accessibility story).

**Databases.** One Postgres server. Seeded template DBs per curriculum
stage (e.g., the issues/projects/users domain reused from the benchmark
suite — learners meet the same domain in tutorials, benchmarks, and
Aluladeck). `CREATE DATABASE ... TEMPLATE` per session; `DROP` on scrub.
Connection limits per session role.

---

## 5. Security (arbitrary code execution as a product)

Non-negotiables, all v1:

- Runner containers: non-root user, read-only rootfs except the workspace
  tmpfs, `no-new-privileges`, seccomp default profile, CPU/memory/pids
  ulimits, wall-clock kill (snippet 15s, app run capped per lease).
- **No network egress** from runners except the Postgres sidecar (compose
  network isolation; runners on an internal network with only postgres and
  the server reachable). This kills crypto-mining, SSRF, and exfil in one
  stroke.
- Workspace disk quota (tmpfs size); output streams truncated at a byte
  cap (compiler error spam is real).
- Rate limits per IP on lease and run; global concurrent-run ceiling is
  the pool size by construction.
- Periodic runner recycle (restart container every M leases) as
  defense-in-depth on top of scrubbing.
- The preview iframe is sandboxed (`sandbox` attribute) and served from
  the `/preview/` path of the same origin — acceptable v1; a separate
  preview domain (cookie isolation) is the first hardening follow-up if
  the site ever carries credentials worth stealing (v1 has none by
  design — no accounts).

---

## 6. Content architecture

```
content/
  tutorial/
    01-setup/
      01-welcome/            # section index + part intro
      02-your-first-app/
        README.md            # the narrative (Phoenix-guide voice)
        meta.json            # { runtime: "app", template: "skeleton",
                             #   focus: ["Sources/App/Main.swift"] }
        app-a/               # learner's starting diff vs. the template
        app-b/               # solution diff
    02-basics/ ...
  guides/                    # the plain-docs track (§8)
  reference/                 # generated DocC drop point (not authored here)
```

Exercises store *diffs against a named CLI template*, not whole apps —
that is what keeps alula-cli the single source of truth and keeps 60+
exercises maintainable when Alula's API moves. CI materializes
template+diff into full workspaces, **builds and runs every `app-b`
solution, and executes every snippet solution**, so an Alula release that
breaks a tutorial step breaks the tutorial's CI, not a learner's morning.
(The benchmark suite's lesson, applied: the conformance check exists
before the content ships.)

`meta.json` declares: runtime tier, template + traits, focused files,
editable-file allowlist, expected-output assertions (for CI), and the DB
template if any.

---

## 7. Curriculum

Structured as parts; each exercise is one concept, Svelte-tutorial
granularity (5–15 minutes). Titles are working titles. The *(runtime: …)*
labels below are the original plan; the `app`/`app+db` execution tiers were
built and then removed (see STATUS.md), so the shipped runtimes are
`none`/`snippet`/`db`/`local` and `site/src/lib/curriculum.ts` is the source
of truth for what actually exists.

**Part 0 — Setup** *(mirrors the CLI; runtime: none/snippet)*
Installing Swift and alula-cli · `alula new` and the tier/trait model ·
project anatomy (Package.swift, alula.yaml, the module list) · running
locally, and how the in-browser workspace corresponds to it.

**Part 1 — Alula basics** *(runtime: local)*
Bootstrap, modules, and the composition root (what `alulaComposeModules`
wires, in what order) ·
first route with `@Controller`/`@GetRoute` · path/query parameters ·
request bodies and content negotiation (JSON *and* forms out of the box —
the round-1 benchmark finding, taught as a feature) · responses, status
codes, `HTTPError` · cookies and redirects (the progressive-enhancement
login built this session becomes the exercise) · static assets and the
asset pipeline (ETags) · middleware and pipeline lanes · configuration
(alula.yaml, env, `@Settings`).

**Part 2 — Data with Hangar and Changeset** *(runtime: snippet → db)*
The Ecto-guides arc, adapted: `@Entity`/`@ID`/`@Column` and what the macro
generates · Repo and first queries · predicates as compiled Swift
(`debugSQL` as a teaching device — every query exercise *shows the SQL*,
which is the pedagogical jackpot of the snippet tier) · order/limit/
projections/aggregates · **Changeset**: casting, validation, error
shapes, changeset-driven insert/update, rendering errors into a form
(bridges back to Part 1's forms) · associations and `Loadable` — why
unloaded throws · preloading and the N+1 story (taught with the measured
5× number) · `@HasMany(through:)` · joins, aliases, self-joins,
three-table · transactions, savepoints, isolation, retry ·
`Multi` (Ecto.Multi's arc) · bulk insert/update/delete · soft delete ·
pagination · CTEs · streaming · diagnostics and `EXPLAIN` (the N+1
detector closes the loop on the preloading lesson).

**Part 3 — Intermediate web** *(runtime: app+db)*
Wiring Hangar into Alula (request-scoped repos, `Repo(connection:inTransaction:)`
— the guide the silent-wrong-answer bug demands) · authentication: the
TokenValidator seam, sessions vs. bearer, the login flow end-to-end ·
file uploads, multipart, resumable (tus) · server-sent events · scheduled
jobs (`@Scheduler`) · the actuator (health/metrics) · error handling and
logging conventions · **testing** (AlulaWebTesting's in-memory transport;
test-first exercises — a differentiator no comparable tutorial does well).

**Part 4 — Advanced: realtime and beyond** *(runtime: app+db)*
WebSockets raw, then why Channels · the envelope protocol · join as the
authorization gate · handle/reply/broadcast · fan-out from HTTP handlers
(the benchmark's key integration point, now a lesson) · Presence: track,
state-then-diffs, the metas model, and the O(N²) join-storm caveat
(measured — teach the limitation honestly) · heartbeats and the four
teardown paths · testing channels (ChannelsTesting) · PubSub and the
clustering seams (prose + diagram; what changes when you add Valkey — no
live cluster) · capstone: the live issue board, assembled from everything
(identical to the benchmark app, which is CI-conformance-tested — the
capstone can never silently rot) · deployment guide (systemd, Docker,
strip-your-binary — the measured 75% size reduction, reverse proxy,
health checks).

**Part 5 — Authoring your own modules** *(runtime: local)*
The seam every subsystem (yours and the framework's) is built on, taught by
writing one. A `AlulaModule` is a value: your first module and providing a
value by type (the `// alula:hand-registered` marker, the required explicit
type annotation) · modules that depend on modules (`dependencies` as an
inclusion edge, an `init` the composition root satisfies by type,
configuration and another module's value; ambiguity is a build error) ·
contributing routes, channels, and middleware as `[RouteRegistration]` /
`[ChannelRegistration]` / `[MiddlewareRegistration]` values the root
aggregates · a module that runs something (`var service:`,
`cancelWhenGracefulShutdown`, shutdown phases, the provide-vs-take-the-graph
cycle rule) · packaging a module in its own library package, installed by
listing it — the shape `AlulaSecurityModule` and friends already ship in.

Changeset appears both inside Part 2 (its natural home, Ecto-style) and as
a standalone guide in the plain-docs track for direct linking.

---

## 7a. Does the benchmark app actually cover this curriculum? (Audited, not assumed)

Asked directly and checked against source rather than answered from
impression. **No — narrower than the plan first implied, and by design:
the benchmark app was built to measure a specific capability's cost, not
for curriculum breadth.** Verified by grepping every `import Alula*` in
`benchmark/alula-app/Sources/App/*.swift`:

| Actually exercised | Never exercised |
|---|---|
| `AlulaCore`, `AlulaWeb`, `AlulaTransport` | `AlulaConfig`/`AlulaConfigCore` (hand-rolled `ProcessInfo` env lookup *on purpose* — see the code comment) |
| `AlulaChannels`, `AlulaPubSub` (**local only** — never `ClusteredPubSub`) | `AlulaSecurityCore` (hand-rolled `TokenService` *on purpose*, specifically to keep `AlulaSecurityModule` from resolving) |
| `AlulaPresence` (**single-node only** — never gossip/membership-monitor) | `AlulaActuator`, `AlulaScheduler`/`AlulaCronCore` — never registered |
| | `AlulaWebTesting`/`AlulaChannelsTesting`/`AlulaPubSubTesting` — the app is validated by an *external* Node harness, not Alula's own in-process test doubles |
| | SSE, multipart/resumable uploads — absent entirely |

That is 7 of ~19 library products, and two of those seven are themselves
scoped down (no cluster path). This is not a defect in the benchmark
suite — round 2's whole methodology depended on a narrow, precisely
measured surface — but it means **the benchmark app cannot be the sole
proof-of-work backing Parts 1, 3, and the non-realtime half of 4.**

**The good news, found in the same audit that found the gap:** alula-cli's
`demo` tier already closes essentially all of it, and — per §2 — its
tutorial is CI-verified against real code today:

```
import AlulaActuator    import AlulaDataPostgres   import AlulaScheduler
import AlulaCache       import AlulaMigrate        import AlulaSchedulerPostgres
import AlulaChannels    import AlulaMigrateCLI     import AlulaSecurityCore
import AlulaCore        import AlulaPresence       import AlulaTransport
                          import AlulaPubSub         import AlulaWeb
```

And `TUTORIAL.md` narrates exactly the parts the benchmark app skips —
Stage 3.2 "Authentication, brought rather than built" (real
`AlulaSecurityCore`, not a hand-rolled `TokenService`), Stage 3.6
"Caching the expensive reads" (`AlulaCache`), Stage 3.7 "Work on a
schedule" including "running once when there really are several
servers" (`AlulaScheduler`'s multi-server story — prose-level, matching
this plan's own no-live-cluster stance, not a contradiction of it).

**Correction to Parts 2 and 3 above, and to §2's "prior art":**

- **Part 2's framing was wrong in relationship, not in content.** Hangar
  is not a peer of alula-data in the curriculum — alula-data's Postgres
  driver is *built on* Hangar. Part 2 should teach Hangar first (as
  planned) and then introduce alula-data as "the seam Alula itself
  builds on top of what you just learned" — migrations
  (`AlulaMigrate`/`AlulaMigrateCLI`), the `DataSource`/cache protocols,
  and the Valkey drivers — rather than treating persistence as closed
  once Hangar is covered.
- **Part 3 is not "design curriculum from scratch"; it is "adapt an
  existing, CI-verified tutorial."** Auth, caching, and scheduling
  exercises should be built from `TUTORIAL.md`'s Stages 3.2/3.6/3.7 and
  the `demo` template, not invented against an unproven reference. This
  meaningfully de-risks Part 3, which was the least-grounded section of
  the original curriculum draft.
- **The benchmark app's remaining, real, unique value** is narrower and
  sharper than "general reference": it is the source for (a) the
  measured claims the curriculum cites verbatim (content-negotiation,
  the 5× preload ratio, build-time/size numbers, the round-2 LOC deltas)
  and (b) the channels+presence capstone specifically *because* it has a
  hand-built comparison stack (Hummingbird) proving what the framework is
  worth — a teaching angle neither the CLI tutorial nor `alula-data`'s
  docs can offer, since neither was built to be compared against a
  hand-rolled alternative.
- Testing content (Part 3) still has no proven exercise source in either
  place at the depth wanted — `AlulaWebTesting`/`AlulaChannelsTesting`
  are used in Alula's *own* test suite but not walked through
  pedagogically anywhere yet. Flagged as a genuine open item, not papered
  over: this section needs fresh exercise-writing, verified against the
  testing modules directly before publishing, the same way every other
  claim in this plan was checked against source rather than assumed.

---

## 8. The plain-documentation track

Not exercise text with the interactivity removed — a parallel set of
guides in the hexdocs tradition, one page per topic, readable start to
finish. Voice and craft rules (the Phoenix/Ecto bar, made concrete):

- Second person, present tense, direct: "You fetch the user, then…" —
  never "the user can be fetched."
- Every concept demonstrated with a complete, runnable snippet — no
  ellipses in code, no pseudo-code; CI executes guide snippets too.
- Show the failure before the feature where honest (the N+1 before
  preload; the trapped precondition before the thrown error) — Ecto's
  signature move, and this codebase's own documented style.
- Name the why in the same breath as the what; every "must" gets its
  reason.
- Cross-link guides ↔ tutorial exercises ↔ DocC API reference in both
  directions. Guides live in `content/guides/`; API reference is the
  existing DocC catalogs, built with `--transform-for-static-hosting` and
  served under `/reference/` — narrative here, symbols there, no
  duplication.

Initial guide set: Up and Running · Routing and Controllers · Requests &
Responses · Configuration · Hangar: Getting Started · Queries · Changesets ·
Associations & Preloading · Transactions & Multi · Testing ·
Channels · Presence · Deployment. (Several can be seeded from the
already-strong Hangar README/DocC prose.)

### 8a. DocC → GitHub Pages: current state, and what's actually missing

Asked directly: is this already a CI step? **Half of it is — and the half
that exists lives in `alula`/`alula-data`'s CI today, not anywhere that
publishes.** Checked against the real workflow
(`alula/.github/workflows/ci.yml`, `docs` job):

```yaml
- name: Generate documentation
  env: { ALULA_BUILD_DOCS: "1" }
  run: |
    mkdir -p ./docs
    for target in AlulaCore AlulaConfig … AlulaScheduler; do
      swift package --enable-all-traits \
        --allow-writing-to-directory "./docs/$target" \
        generate-documentation --target "$target" \
        --warnings-as-errors --output-path "./docs/$target"
    done
```

This is a **verification gate, not a publish step**: `--warnings-as-errors`
means a broken symbol link or a stale `Topics` entry fails CI (the exact
"documentation that nothing checks rots into documentation that is
wrong" discipline this plan wants generally) — but the job stops at a
build artifact. No `--transform-for-static-hosting`, no
`--hosting-base-path`, no `actions/upload-pages-artifact` /
`actions/deploy-pages`, no `gh-pages` branch push, and each target lands
in its own disconnected folder with no combined index tying the ~19
modules into one navigable site. `alula-data` is in the same state.
**Nobody is publishing these anywhere today.**

**What Fledge actually needs to add** (worth upstreaming to
`alula`/`alula-data`'s own CI too, independent of this project):

1. Regenerate with the static-hosting flags:
   `generate-documentation --target "$target" \
   --transform-for-static-hosting \
   --hosting-base-path "alula/$target" \
   --output-path "./site/$target"` — the base path must match the
   published URL's path segment or every relative asset link 404s; this
   is the most common DocC-on-Pages mistake and worth a CI smoke-check
   (curl one generated page, grep for the expected base path) rather than
   discovering it live.
2. **A combined landing page.** DocC's per-module archives don't
   self-assemble into a site; write a small generated `index.html`
   (module list → each `./AlulaCore/documentation/alulacore/` etc.) or
   adopt DocC's combined-archive support if the pinned toolchain's
   `swift-docc-plugin` version has matured it by implementation time —
   verify the current flag name/stability against the plugin's own
   CHANGELOG before depending on it, since this has moved across
   releases.
3. **The publish step**, standard and small:
   ```yaml
   - uses: actions/upload-pages-artifact@v3
     with: { path: ./site }
   - uses: actions/deploy-pages@v4
   ```
   plus the repo's Pages source set to "GitHub Actions" (Settings →
   Pages) and a `pages: write` / `id-token: write` permissions block on
   the job.
4. **Hosting split, deliberately:** reference docs deploy to GitHub
   Pages (`alula-framework.github.io/fledge/` or per-repo — decide
   whether Fledge aggregates `alula` + `alula-data` + Hangar's
   docs into one Pages site or links out to each repo's own), fully
   decoupled from the tutorial site's self-hosted VM (§9). This is a
   *better* fit than the plan's original "`/reference/` under the same
   origin" idea: API docs update on Alula's release cadence, not the
   tutorial site's; GitHub Pages is free and needs no runner/compose
   involvement at all. The plain-docs guides (§8) link out to the Pages
   URLs rather than embedding the archives.
5. Trigger on release tag, not every push — DocC generation is not free
   (17+ targets), and reference docs don't need to move on every commit
   to `main`.

This is genuinely new work, not a checkbox — flagged here so "surely
that's already automated" doesn't get assumed again later the way the
CLI tutorial audit above almost was.

---

## 9. Deployment

One VM, `docker compose up -d`, five services: caddy, site, server,
postgres, runner (×N via `deploy.replicas` or compose scale; N templated
into Caddy's static preview routes). CI (GitHub Actions): build runner
image weekly + on Alula/Hangar releases (bakes fresh warm `.build`),
materialize+test all content, build site, push images. `.env` holds the
two or three real secrets. Backups: none needed beyond content (sessions
are disposable; progress is client-side). This is deliberately the most
boring deployment that satisfies "easy."

---

## 10. Delivery milestones

- **M0 — Skeleton + static value.** Repo, compose, Caddy, SvelteKit site
  rendering guides + tutorial *text* (no execution); the guides link out
  to DocC on GitHub Pages (§8a — a real gap, not existing automation:
  static-hosting flags, a combined index, and the actual
  `deploy-pages` step all need building). Deployable and useful on day
  one; this is also the permanent degraded mode.
- **M1 — Snippet tier + Hangar/Changeset curriculum.** Runner pool,
  channel-streamed output, Part 2 interactive through the no-DB lessons.
  Cheapest interactive win, biggest teaching payoff (`debugSQL`).
- **M2 — DB tier.** Template databases, session scrubbing; rest of Part 2.
- **M3 — App tier + preview proxy.** ~~Parts 0–1 interactive; Part 3.~~
  **Built, measured, and reversed.** The tier worked; the economics
  didn't — ~25min warm-ups (35 with `app+db`), a permanently warm 4×8G
  pool for a mostly-reading audience, and the lessons that most needed it
  (static assets, configuration, middleware's log output) were exactly the
  ones it couldn't teach. Parts 1/3/4 ship as prose plus a project run
  locally, which §1 already named as the degraded mode and which is the
  right primary mode above snippet size. The bug-catching this promised is
  real but comes from **CI building the exercises**, not from serving them.
  See STATUS.md; the code is in git history.
- **M4 — Realtime.** ~~WS through the preview proxy; Part 4 + capstone.~~
  Dropped with M3 — it depended on the preview proxy.
- **M5 — Polish/hardening.** Solve-diff UX, search, presence dogfood,
  runner recycle cadence, maybe LSP, maybe REPL console, separate preview
  domain.

Each milestone ships; none blocks the previous from being deployed.

---

## 11. Risks and open questions (with verification steps)

1. **Runner memory/pool sizing.** A leased workspace + swift-frontend
   during builds is the peak. *Verify:* measure RSS during snippet and app
   rebuilds; size N for a 8–16GB VM. (Expect builds ~1–2GB transient →
   N=4–8 on a 16GB box with staggered-run admission.)
2. **Warm-cache invalidation.** SwiftPM occasionally decides to rebuild
   the world (flag drift, resolved-file drift). *Verify:* image build pins
   Package.resolved and runs one no-op build as a smoke gate; supervisor
   treats a >30s snippet build as a poisoned workspace and recycles.
3. **Preview proxy + WebSockets through Caddy path-routing.** Standard,
   but the channels exercises depend on it. *Verify* early in M3 with the
   existing `ws-conformance.js` pointed through the proxy — the suite
   already exists and is the perfect probe.
4. **`swift run --repl` modulemap bug.** Track upstream; retest per
   toolchain release. REPL console remains optional; also verify whether
   lldb's REPL expands macros at all before investing.
5. **CodeMirror Swift highlighting quality.** Legacy mode is basic.
   *Verify* against real exercise code; fallback is a tree-sitter-swift →
   Lezer bridge or shipping highlight-only grammar tweaks (cosmetic risk
   only).
6. **iOS Safari + CodeMirror.** Test early; Svelte's tutorial works on
   mobile and ours should degrade to read-only gracefully there.
7. **Abuse economics.** Even sandboxed, N runners × 60s caps is a small
   free compute faucet. Rate limits + no egress makes it unattractive;
   monitor lease patterns from launch.
8. **Content maintenance cost.** 60+ exercises against a moving framework
   is the real long-term cost. The template+diff+CI design is the
   mitigation; treat any exercise CI failure as an Alula release blocker,
   same as a test.

---

## 12. Decisions taken here (so they don't get re-litigated silently)

- Server-side execution; no wasm, no WebContainers-equivalent. Measured
  latencies make the tiers honest: ~2s snippet, ~8s app run.
- Warm leased pool over spawn-per-session for v1; scrub + recycle +
  no-egress as the compensating controls.
- alula-cli templates are the single source of truth for workspaces;
  exercises are diffs against them.
- Snippet tier (not REPL) is the workhorse; REPL is a stretch console.
- CodeMirror 6, not Monaco. SvelteKit for the whole site including guides.
- Fixed pool size ⇒ static preview proxy config, WS-capable from day one.
- Content CI executes every solution and every guide snippet.
- Same teaching domain (users/projects/issues) across tutorial, benchmark
  suite, and capstone.
- **alula-cli's `TUTORIAL.md` + `demo` tier, not the benchmark app, is
  the primary reference for Parts 1 and 3** (basics, auth, caching,
  scheduling) — audited in §7a after the benchmark app was found to cover
  only 7 of ~19 Alula modules, single-node only. The benchmark app's
  remaining unique role: the measured numbers the curriculum cites, and
  the channels+presence capstone's hand-built-comparison narrative.
- Hangar and `alula-data` are not peer curricula — `alula-data`'s
  Postgres driver depends on Hangar. Teach Hangar first, then
  `alula-data` as what Alula itself builds on top of it (§7a).
- DocC → GitHub Pages is new work, not existing automation (§8a): Alula's
  own CI generates and validates docs (`--warnings-as-errors`) but
  publishes nothing today. Separate hosting from the tutorial site's VM
  entirely — Pages for reference docs, self-hosted for the interactive
  site — rather than serving DocC under `/reference/` on the same origin.

*Grounding for the measured numbers cited above: probes run 2026-08-27 on
the dev machine (headless `swift repl` ✅; `swift run --repl` vs. Hangar ❌
duplicate modulemaps; 1.81s warm one-file rebuild with macros; 7–8s app
incremental; ~73s/~470s clean debug/release) — and the benchmark suite's
RESULTS files in `SwiftAlula/benchmark/` for the framework-level numbers
the curriculum cites.*
