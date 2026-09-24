import { error } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

// `/api/*` and `/socket` are not SvelteKit routes — they belong to the
// Alula backend (`server/`), and something has to put the two behind one
// origin: Caddy in the compose setup, vite's dev proxy under
// `npm run dev` (see ../../../../vite.config.ts, which forwards both,
// `/socket` with `ws: true`).
//
// Reaching the site's own port directly gets you working *pages* and a
// failure on every API call, which reads as a broken endpoint rather than
// a wrong address — the pages working is what makes it confusing.
//
// This deliberately explains rather than proxies. A `+server.ts` cannot
// proxy a WebSocket upgrade, so forwarding `/api` from here would fix the
// visible half and leave `/socket` dead: a session that leases, writes and
// runs, then shows no build output at all, because that arrives over the
// channel. A silent half-working state is worse than an honest refusal.
const explain =
	'The /api routes are served by the Alula backend, not by SvelteKit, and ' +
	'/socket needs a WebSocket proxy this route cannot provide. Use the ' +
	'origin that fronts both: http://localhost/ (Caddy) in the compose setup, ' +
	'or `npm run dev` for local work. The site container port serves pages ' +
	'only — the interactive tiers will not work through it.';

const handler: RequestHandler = () => error(421, explain);

export const GET = handler;
export const POST = handler;
export const PUT = handler;
export const PATCH = handler;
export const DELETE = handler;
