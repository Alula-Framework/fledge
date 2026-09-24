# site

The Fledge frontend — SvelteKit 5, `adapter-node`. See the
[repo root README](../README.md) for the full picture; this is
site-specific development notes only.

## Developing

```sh
npm install
npm run dev
```

Content is read from `../content` (see `src/lib/server/content.ts`) —
there's nothing to build or watch on the content side, markdown is parsed
per request.

## Type-checking

```sh
npm run check
```

Runs in CI on every push/PR (`.github/workflows/site.yml`) alongside a
production build — both must stay clean.

## Building

```sh
npm run build
node build/index.js
```

Not `npm run preview` — that's Vite's own preview server, which doesn't
exercise `adapter-node`'s actual output the way `node build/index.js`
does (that distinction mattered once already: see the commit that added
`CONTENT_ROOT` as an env var rather than a relative path). Set
`CONTENT_ROOT` when running the built server directly, or use
`docker compose up` from the repo root, which sets it for you.
