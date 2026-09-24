<script lang="ts">
	import type { PageData } from './$types';
	let { data }: { data: PageData } = $props();
</script>

<svelte:head>
	<title>{data.outline.title} — Fledge</title>
</svelte:head>

{#if data.doc}
	<article class="prose">
		<h1>{data.outline.title}</h1>
		{@html data.doc.html}
	</article>
{:else}
	<div class="coming-soon">
		<p class="eyebrow">Coming soon</p>
		<h1>{data.outline.title}</h1>
		<p class="desc">{data.outline.description}</p>
		<p class="note">
			This guide is planned but not written yet. It's tracked in the site's content manifest
			(<code>src/lib/guides.ts</code>) — see
			<a href="https://github.com/Alula-Framework/fledge">the repo</a> if you'd like to write it.
		</p>
	</div>
{/if}

<style>
	.coming-soon {
		max-width: 60ch;
	}
	.eyebrow {
		text-transform: uppercase;
		letter-spacing: 0.06em;
		font-size: 0.8rem;
		color: var(--accent);
		font-weight: 700;
	}
	.desc {
		font-size: 1.1rem;
		color: var(--muted);
	}
	.note {
		font-size: 0.9rem;
		color: var(--muted);
		border-left: 3px solid var(--line);
		padding-left: 14px;
		margin-top: 24px;
	}
</style>
