// The full planned curriculum, transcribed from PLAN-flight-school.md §7.
//
// This is the site's source of truth for navigation and for distinguishing
// "not written yet" from "doesn't exist" — a slug listed here with no
// matching file under content/tutorial/<part>/ renders a "coming soon"
// placeholder (using this manifest's title/description) instead of a 404.
// That is deliberate: most of the curriculum is planned but not yet
// authored, and a broken link reads as a bug while a labeled placeholder
// reads as a map. See site/src/lib/server/content.ts for how a slug is
// resolved against real files.

export interface ExerciseOutline {
	slug: string;
	title: string;
	description: string;
}

export interface PartOutline {
	slug: string;
	title: string;
	summary: string;
	/// How a part's exercises are meant to be run.
	///
	/// `snippet` is the only interactive one: those exercises carry a
	/// sibling `.swift` file and get the embedded editor. `local` means the
	/// code is real and CI-verified — each exercise keeps an `app-b`
	/// solution built against a `flight new` template — but the reader runs
	/// it in their own project rather than in the page. `none` is prose
	/// with nothing to run.
	///
	/// `app`/`app+db` were execution tiers that got built and then removed;
	/// see STATUS.md for why. Nothing serves them, so nothing should claim
	/// them.
	runtime: 'none' | 'snippet' | 'db' | 'local';
	exercises: ExerciseOutline[];
}

export const curriculum: PartOutline[] = [
	{
		slug: '00-setup',
		title: 'Part 0 — Setup',
		summary: 'Mirrors flight-cli directly: install, generate, understand what you got.',
		runtime: 'none',
		exercises: [
			{
				slug: '01-install',
				title: 'Installing Swift and flight-cli',
				description: 'Get a Swift toolchain and the flight command on your machine.'
			},
			{
				slug: '02-flight-new',
				title: 'flight new, and the tier/trait model',
				description: 'Three starting points, and how dependencies stay opt-in.'
			},
			{
				slug: '03-anatomy',
				title: 'Project anatomy',
				description: 'What flight new skeleton actually generates, file by file.'
			},
			{
				slug: '04-running',
				title: 'Running it locally',
				description: 'swift run, swift test, and what this site’s editor will map to.'
			}
		]
	},
	{
		slug: '01-basics',
		title: 'Part 1 — Flight basics',
		summary: 'Bootstrap, routing, requests and responses, middleware, configuration.',
		runtime: 'local',
		exercises: [
			{
				slug: '01-bootstrap',
				title: 'Bootstrap, modules, and the composition root',
				description: 'What the composition root wires, and in what order.'
			},
			{
				slug: '02-first-route',
				title: 'Your first route',
				description: '@Controller and @GetRoute, and why there is no route table to find.'
			},
			{
				slug: '03-parameters',
				title: 'Path and query parameters',
				description: 'Typed extraction from the URL, before the handler body runs.'
			},
			{
				slug: '04-request-bodies',
				title: 'Request bodies and content negotiation',
				description: 'JSON and forms, both handled, with no decoder you have to write.'
			},
			{
				slug: '05-responses',
				title: 'Responses, status codes, and HTTPError',
				description: 'Shaping what a handler sends back, and how it fails on purpose.'
			},
			{
				slug: '06-cookies',
				title: 'Cookies and redirects',
				description: 'A progressive-enhancement login: works with and without JavaScript.'
			},
			{
				slug: '07-static-assets',
				title: 'Static assets and the asset pipeline',
				description: 'ETags, and serving a real frontend build alongside your API.'
			},
			{
				slug: '08-middleware',
				title: 'Middleware and pipeline lanes',
				description: 'Ordering cross-cutting concerns explicitly, not by registration accident.'
			},
			{
				slug: '09-configuration',
				title: 'Configuration',
				description: 'flight.yaml, environment variables, and @Settings.'
			}
		]
	},
	{
		slug: '02-data',
		title: 'Part 2 — Data with Hangar and Changeset',
		summary: 'Entities, queries, changesets, associations, transactions, and what flight-data builds on top.',
		runtime: 'snippet',
		exercises: [
			{
				slug: '01-entities',
				title: '@Entity, @ID, @Column',
				description: 'What the macro generates, and why a typo becomes a compile error.'
			},
			{
				slug: '02-first-queries',
				title: 'Repo and first queries',
				description: 'A query is a value. Nothing runs until a Repo executes it.'
			},
			{
				slug: '03-predicates',
				title: 'Predicates as compiled Swift',
				description: 'debugSQL as a teaching device — see the SQL every query renders to.'
			},
			{
				slug: '04-changesets',
				title: 'Changesets',
				description: 'Casting, validation, error shapes, and changeset-driven writes.'
			},
			{
				slug: '05-associations',
				title: 'Associations and Loadable',
				description: 'Why an unloaded association throws instead of returning empty.'
			},
			{
				slug: '06-preloading',
				title: 'Preloading and the N+1 story',
				description: 'The measured 5× — batched queries instead of one-per-parent.'
			},
			{
				slug: '07-joins',
				title: 'Joins, aliases, self-joins',
				description: 'Two-table, three-table, and the same table joined to itself.'
			},
			{
				slug: '08-transactions',
				title: 'Transactions, savepoints, isolation, retry',
				description: 'Nested transactions become savepoints; serialization failures can retry themselves.'
			},
			{
				slug: '09-multi',
				title: 'Multi',
				description: 'Units of work whose steps are decided before they run.'
			},
			{
				slug: '10-bulk-writes',
				title: 'Bulk insert, update, delete',
				description: 'One statement across every matching row, with the count returned.'
			},
			{
				slug: '11-flight-data',
				title: 'flight-data: what Flight builds on top of Hangar',
				description: 'Migrations, the DataSource/cache seam, and the Valkey drivers.'
			},
			{
				slug: '12-diagnostics',
				title: 'Diagnostics and EXPLAIN',
				description: 'Closing the loop on the preloading lesson: catching an N+1 you missed.'
			}
		]
	},
	{
		slug: '03-intermediate',
		title: 'Part 3 — Intermediate web',
		summary: 'Auth brought not built, uploads, jobs, the actuator, and testing.',
		runtime: 'local',
		exercises: [
			{
				slug: '01-repo-wiring',
				title: 'Wiring Hangar into Flight',
				description: 'Leasing a connection per operation with withRepo, and the connection-affinity bug this guide exists to prevent.'
			},
			{
				slug: '02-authentication',
				title: 'Authentication, brought rather than built',
				description: 'The TokenValidator seam, sessions vs. bearer tokens, a real login flow.'
			},
			{
				slug: '03-uploads',
				title: 'File uploads',
				description: 'Multipart, and resumable uploads for anything too large to retry blind.'
			},
			{
				slug: '04-sse',
				title: 'Server-sent events',
				description: 'A one-way stream, for when a socket is more than the problem needs.'
			},
			{
				slug: '05-scheduling',
				title: 'Work on a schedule',
				description: '@Scheduler, and running a job once when there really are several servers.'
			},
			{
				slug: '06-actuator',
				title: 'The actuator',
				description: 'Health, info, and metrics — absent entirely in production unless you ask.'
			},
			{
				slug: '07-testing',
				title: 'Testing',
				description: 'Unit tests as direct struct calls, with a small end-to-end tier.'
			}
		]
	},
	{
		slug: '04-advanced',
		title: 'Part 4 — Advanced: realtime and beyond',
		summary: 'Channels, Presence, PubSub, and the capstone realtime board.',
		runtime: 'local',
		exercises: [
			{
				slug: '01-websockets',
				title: 'WebSockets raw, then why Channels',
				description: 'What you would build by hand, before seeing what Channels replaces.'
			},
			{
				slug: '02-channels',
				title: 'The envelope protocol',
				description: 'Join as the authorization gate; handle, reply, and broadcast.'
			},
			{
				slug: '03-fanout',
				title: 'Fan-out from HTTP handlers',
				description: 'An ordinary POST route, and the socket subscribers it reaches.'
			},
			{
				slug: '04-presence',
				title: 'Presence',
				description: 'Track, state-then-diffs, the metas model, and the measured join-storm caveat.'
			},
			{
				slug: '05-teardown',
				title: 'Heartbeats and the four teardown paths',
				description: 'Clean close, abrupt drop, explicit leave, and the heartbeat reaper.'
			},
			{
				slug: '06-testing-channels',
				title: 'Testing channels',
				description: 'FlightChannelsTesting, and asserting on a protocol instead of a socket.'
			},
			{
				slug: '07-clustering',
				title: 'PubSub and the clustering seams',
				description: 'What changes when you add Valkey — in prose and diagrams, not a live cluster.'
			},
			{
				slug: '08-capstone',
				title: 'Capstone: the live issue board',
				description: 'Assembled from everything — identical to the benchmark app, conformance-tested from outside.'
			},
			{
				slug: '09-deployment',
				title: 'Deployment',
				description: 'systemd, Docker, stripping your release binary, and a reverse proxy in front of it.'
			}
		]
	},
	{
		slug: '05-modules',
		title: 'Part 5 — Authoring your own modules',
		summary:
			'Writing a FlightModule: providing components, values, routes, and a service, all wired by the composition root — the seam every subsystem (yours and the framework’s) is built on.',
		runtime: 'local',
		exercises: [
			{
				slug: '01-your-first-module',
				title: 'Your first module',
				description: 'A FlightModule is a value: what it declares, and how the composition root wires it.'
			},
			{
				slug: '02-providing-values',
				title: 'Modules that depend on modules',
				description:
					'Pull in a stack with dependencies, and receive configuration and another module’s value through your init.'
			},
			{
				slug: '03-routes-and-channels',
				title: 'Contributing routes, channels, and middleware',
				description:
					'A module offers [RouteRegistration] / [ChannelRegistration] / [MiddlewareRegistration]; the root aggregates them.'
			},
			{
				slug: '04-a-service',
				title: 'A module that runs something',
				description:
					'Owning a long-running service, and the provide-vs-take-the-graph rule that keeps composition acyclic.'
			},
			{
				slug: '05-packaging',
				title: 'Packaging a module for reuse',
				description: 'Shipping a module in its own package, the way FlightSecurityModule and friends do.'
			}
		]
	}
];

export function findPart(slug: string): PartOutline | undefined {
	return curriculum.find((part) => part.slug === slug);
}

export function findExercise(
	partSlug: string,
	exerciseSlug: string
): { part: PartOutline; exercise: ExerciseOutline } | undefined {
	const part = findPart(partSlug);
	const exercise = part?.exercises.find((e) => e.slug === exerciseSlug);
	return part && exercise ? { part, exercise } : undefined;
}

export interface AdjacentExercise {
	partSlug: string;
	partTitle: string;
	slug: string;
	title: string;
}

/**
 * Prev/next across the *whole* curriculum, not just within one part — the
 * last exercise of a part points at the first exercise of the next one,
 * rather than dead-ending. This is what the exercise page's pager uses;
 * content itself should never hand-write "Next:" links (they drift, and
 * they'd just be reimplementing this in prose — content/tutorial's files
 * intentionally have none, on purpose, not by oversight).
 */
export function adjacentExercises(
	partSlug: string,
	exerciseSlug: string
): { prev: AdjacentExercise | null; next: AdjacentExercise | null } {
	const flat: AdjacentExercise[] = curriculum.flatMap((part) =>
		part.exercises.map((exercise) => ({
			partSlug: part.slug,
			partTitle: part.title,
			slug: exercise.slug,
			title: exercise.title
		}))
	);
	const index = flat.findIndex((e) => e.partSlug === partSlug && e.slug === exerciseSlug);
	if (index === -1) return { prev: null, next: null };
	return {
		prev: index > 0 ? flat[index - 1] : null,
		next: index < flat.length - 1 ? flat[index + 1] : null
	};
}
