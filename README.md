# Fledge

An interactive tutorial and documentation site for
[Alula](https://github.com/Alula-Framework/alula),
[Hangar](https://github.com/Alula-Framework/hangar), and Changeset — in the
mold of [Svelte's tutorial](https://svelte.dev/tutorial), with a parallel
plain-documentation track written at the level of detail Phoenix and Ecto
readers expect.

Full design and rationale: [`PLAN.md`](PLAN.md). Current build status,
what's real vs. planned: [`STATUS.md`](STATUS.md).

## Structure

```
site/       Svelte 5 + SvelteKit — the frontend, guides + tutorial UI
content/    Markdown: tutorial exercises and plain-doc guides
scripts/    Content integrity checks, the DocC → Pages index generator
```

`server/` (an Alula backend for the interactive execution tiers) and
`runner/` (the sandboxed code-execution pool) are both real — see
`STATUS.md` for what's actually been verified end to end and what's still
open.

## Running locally

```bash
cd site
npm install
npm run dev
```

Or the full deployment shape:

```bash
docker compose up -d --build
```

**Pass `--build`.** Content lives in `content/` and is bind-mounted into
the site container, so editing a guide or exercise takes effect on the
next request with no rebuild. The site's own *code* is baked into the
image, and the two drift apart the moment a change touches both — which is
exactly what adding a new content shape does.

The failure mode is quiet rather than loud, so it's worth recognising: a
stale image can't read newer content, the loaders return nothing, and
every affected page renders a placeholder. Since M3 that placeholder says
so explicitly ("content present, but unreadable by this build") rather
than claiming the exercise is unwritten, but the fix is the same either
way — rebuild:

```bash
docker compose up -d --build site
```

The runner image is the expensive one (it warms a full SwiftPM build cache
per execution tier — roughly 25 minutes cold), so rebuild `site` on its
own when that's all that changed.

### What's interactive, and what isn't

Part 2 (Hangar and Changeset) runs in the browser: an editor, a real
compile, real output. That tier is one file and a ~2s rebuild, and
`debugSQL` printing the SQL beside the Swift that produced it is the whole
reason it exists.

Everything else is prose plus code you run locally with `alula new`. An
`app` tier that ran whole Alula applications in the browser was built and
then removed — it worked, but it needed a permanently warm pool of large
containers and ~25-minute cold starts to show a learner something
`alula new` shows them in two minutes. STATUS.md has the full reasoning.

### Reach it on port 80, not the site's own port

`/api/*` and `/socket` are not SvelteKit routes — they belong to the
Alula backend in `server/`, and Caddy is what puts the two behind a
single origin. Open `http://localhost/`. Hitting the site container's own
port instead gets you perfectly working *pages* and a failure on every API
call, which reads as a broken endpoint rather than a wrong port; those
paths now answer `421 Misdirected Request` explaining as much, instead of
a bare 404.

`npm run dev` has no such problem — vite's dev proxy forwards `/api` and
`/socket` for exactly this reason.

### Testing the API by hand

Send a body, even an empty one: `curl -X POST -d '' http://localhost/api/session`.
A `curl -X POST` with no `-d` at all sends neither `Content-Length` nor a
body, and Caddy holds that request open rather than forwarding it — the
call appears to hang. The backend itself answers such a request fine when
reached directly, and browsers always set `Content-Length`, so this is a
hand-testing trap rather than something clients hit.

## Exercise CI

`scripts/check-exercises.py` builds every exercise's real code and *runs*
the ones that can be run:

```bash
# needs a sibling alula-cli checkout for the app-tier templates
python3 scripts/check-exercises.py

# with a seeded database, the db-tier snippets run rather than just build
python3 scripts/check-exercises.py \
  --database-url postgres://postgres:pw@127.0.0.1:5432/fledge_seed
```

Running matters more than building, and that isn't a stylistic preference:
the last real bug this caught — `repo.one` on a non-unique predicate —
**compiled cleanly** and only failed when executed. A build-only check
would have shipped it. `.github/workflows/exercises.yml` runs the whole
thing on every PR and weekly, the schedule being there because the usual
cause of a break is an upstream release rather than an edit here.

## Contributing content

Every markdown file under `content/` needs frontmatter (`title`,
`description`) and is checked by `scripts/check-content-links.py` in CI —
a broken relative link fails the build rather than shipping. New tutorial
exercises and guides also need an entry in `site/src/lib/curriculum.ts` or
`site/src/lib/guides.ts` respectively; that manifest is what lets the site
show a labeled "coming soon" placeholder for planned-but-unwritten content
instead of either faking it or 404ing.

## License

MIT. See [LICENSE](LICENSE).
