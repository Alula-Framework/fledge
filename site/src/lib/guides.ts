// The planned plain-documentation track, transcribed from
// PLAN-fledge.md §8. Same "coming soon vs. 404" role as
// curriculum.ts — see the comment there.

export interface GuideOutline {
	slug: string;
	title: string;
	description: string;
	category: string;
}

export const guides: GuideOutline[] = [
	{
		slug: 'up-and-running',
		title: 'Up and Running',
		description: 'From an empty directory to a running Alula app in one page.',
		category: 'Alula'
	},
	{
		slug: 'routing-and-controllers',
		title: 'Routing and Controllers',
		description: '@Controller, path parameters, and how the registration plugin finds your routes.',
		category: 'Alula'
	},
	{
		slug: 'requests-and-responses',
		title: 'Requests & Responses',
		description: 'Content negotiation, status codes, and shaping errors on purpose.',
		category: 'Alula'
	},
	{
		slug: 'configuration',
		title: 'Configuration',
		description: 'alula.yaml, environment variables, and @ConfigValue/@Settings.',
		category: 'Alula'
	},
	{
		slug: 'hangar-getting-started',
		title: 'Hangar: Getting Started',
		description: 'Models are structs, queries are values, and a typo is a compile error.',
		category: 'Hangar'
	},
	{
		slug: 'hangar-queries',
		title: 'Queries',
		description: 'Predicates, joins, aggregates, and projections that decode into your own types.',
		category: 'Hangar'
	},
	{
		slug: 'hangar-changesets',
		title: 'Changesets',
		description: "Validated, tracked writes: Hangar's answer to Ecto.Changeset.",
		category: 'Hangar'
	},
	{
		slug: 'hangar-preloading',
		title: 'Associations & Preloading',
		description: 'Why unloaded throws, and how batched preloading avoids N+1.',
		category: 'Hangar'
	},
	{
		slug: 'hangar-transactions',
		title: 'Transactions & Multi',
		description: 'Savepoints, isolation levels, retry-on-serialization-failure, and Multi.',
		category: 'Hangar'
	},
	{
		slug: 'testing',
		title: 'Testing',
		description: 'AlulaWebTesting, AlulaChannelsTesting, and three sizes of test.',
		category: 'Alula'
	},
	{
		slug: 'channels',
		title: 'Channels',
		description: 'The envelope protocol, join as the authorization gate, and fan-out.',
		category: 'Realtime'
	},
	{
		slug: 'presence',
		title: 'Presence',
		description: 'Track, state-then-diffs, and the measured cost of a join storm.',
		category: 'Realtime'
	},
	{
		slug: 'deployment',
		title: 'Deployment',
		description: 'systemd, Docker, stripping your release binary, and a reverse proxy.',
		category: 'Alula'
	}
];

export function findGuide(slug: string): GuideOutline | undefined {
	return guides.find((g) => g.slug === slug);
}

export function guidesByCategory(): Map<string, GuideOutline[]> {
	const map = new Map<string, GuideOutline[]>();
	for (const guide of guides) {
		const list = map.get(guide.category) ?? [];
		list.push(guide);
		map.set(guide.category, list);
	}
	return map;
}
