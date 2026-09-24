// The browser-side half of PLAN §4's execution module: talks to `server`'s
// `/api/session*` routes and joins the `session:<id>` Channel topic those
// routes stream build/run output onto. Same-origin `/api`/`/socket` paths
// throughout — Caddy proxies both to `server` in production
// (see ../../../../Caddyfile), and `vite.config.ts`'s dev proxy does the
// same for `npm run dev`, so this code never needs an environment-specific
// base URL.

export interface SessionInfo {
	sessionId: string;
	topic: string;
}

/** One channel push, normalized from the wire envelope — see the doc
 *  comment on `joinChannel` for the exact envelope shapes this unwraps. */
export interface RunEvent {
	event: string;
	data: string;
}

async function post(path: string, body?: unknown): Promise<Response> {
	return fetch(path, {
		method: 'POST',
		headers: body === undefined ? undefined : { 'Content-Type': 'application/json' },
		body: body === undefined ? undefined : JSON.stringify(body)
	});
}

/** Reuses the session the `fs_session` cookie already names, or claims a
 *  fresh runner from the pool — see server/Sources/Server/SessionService.swift.
 *  Safe to call every time a learner opens an exercise page: idempotent
 *  when the cookie is already live. */
export async function createSession(): Promise<SessionInfo> {
	const response = await post('/api/session');
	if (!response.ok) {
		const problem = await response.json().catch(() => null);
		throw new Error(problem?.detail ?? `could not start a session (${response.status})`);
	}
	return response.json();
}

export async function writeSnippet(content: string): Promise<void> {
	const response = await post('/api/session/write', { content });
	if (!response.ok) {
		const problem = await response.json().catch(() => null);
		throw new Error(problem?.detail ?? `could not save your code (${response.status})`);
	}
}

/** Kicks off the run; returns as soon as the server has dispatched it — the
 *  actual output arrives over the channel `joinChannel` is (or should
 *  already be) listening on, never in this response. */
export async function runSnippet(): Promise<void> {
	const response = await post('/api/session/run');
	if (!response.ok) {
		const problem = await response.json().catch(() => null);
		throw new Error(problem?.detail ?? `could not start the run (${response.status})`);
	}
}

export async function resetSnippet(): Promise<void> {
	const response = await post('/api/session/reset');
	if (!response.ok) {
		const problem = await response.json().catch(() => null);
		throw new Error(problem?.detail ?? `could not reset your workspace (${response.status})`);
	}
}

/**
 * Joins `topic` over the Channels socket and calls `onEvent` for every
 * build/run push. Envelope shape (matching SessionService.swift's
 * broadcasts and AlulaChannels' wire protocol exactly):
 *
 *     {"ref": null, "topic": "session:<id>", "event": "build_output", "payload": {"data": "..."}}
 *
 * `ref: null` marks a genuine broadcast; `ref` matching the join's own ref
 * ("1") is the join's `alula:reply` acknowledgment, not output, and is
 * ignored. `alula:error` (a join refusal — e.g. the session already
 * expired) is surfaced as a synthetic `channel_error` event regardless of
 * `ref`, since it's the one server-originated message this channel ever
 * sends that isn't a plain broadcast. This channel never sends anything
 * back after the join — see `SessionChannel.handle` on the server, which
 * always replies `.none`.
 *
 * Returns a function that closes the socket — call it when the exercise
 * page unmounts.
 */
export function joinChannel(topic: string, onEvent: (event: RunEvent) => void): () => void {
	const scheme = location.protocol === 'https:' ? 'wss:' : 'ws:';
	const socket = new WebSocket(`${scheme}//${location.host}/socket`);

	socket.addEventListener('open', () => {
		socket.send(JSON.stringify({ ref: '1', topic, event: 'alula:join', payload: {} }));
	});

	socket.addEventListener('message', (message) => {
		const envelope = JSON.parse(message.data as string);
		if (envelope.topic !== topic) return;
		if (envelope.event === 'alula:error') {
			onEvent({ event: 'channel_error', data: envelope.payload?.reason ?? 'join refused' });
			return;
		}
		if (envelope.ref !== null) return; // the join's own alula:reply — nothing to show
		onEvent({
			event: envelope.event,
			data: envelope.payload?.data ?? envelope.payload?.message ?? ''
		});
	});

	return () => socket.close();
}
