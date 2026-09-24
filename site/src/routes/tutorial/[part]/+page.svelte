<script lang="ts">
	import type { PageData } from './$types';
	let { data }: { data: PageData } = $props();
</script>

<svelte:head>
	<title>{data.part.title} — Fledge</title>
</svelte:head>

<p class="crumb"><a href="/tutorial">Tutorial</a> / {data.part.title}</p>
<h1>{data.part.title}</h1>
<p class="lead">{data.part.summary}</p>

<ol class="exercises">
	{#each data.part.exercises as exercise, i}
		<li class:stub={!data.written[i]}>
			<a href="/tutorial/{data.part.slug}/{exercise.slug}">
				<span class="num">{i + 1}</span>
				<span>
					<h2>{exercise.title}</h2>
					<p>{exercise.description}</p>
				</span>
				{#if !data.written[i]}<span class="tag">coming soon</span>{/if}
			</a>
		</li>
	{/each}
</ol>

<style>
	.crumb {
		font-size: 0.85rem;
		color: var(--muted);
	}
	.lead {
		color: var(--muted);
		max-width: 60ch;
	}
	.exercises {
		list-style: none;
		padding: 0;
		margin: 28px 0 0;
		display: flex;
		flex-direction: column;
		gap: 10px;
	}
	.exercises a {
		display: flex;
		gap: 16px;
		align-items: center;
		padding: 14px 16px;
		border: 1px solid var(--line);
		border-radius: 10px;
		color: var(--ink);
	}
	.exercises a:hover {
		text-decoration: none;
		border-color: var(--accent);
	}
	.stub a {
		opacity: 0.65;
	}
	.num {
		font: 700 1rem var(--mono);
		color: var(--muted);
		min-width: 1.5em;
	}
	h2 {
		margin: 0 0 2px;
		font-size: 1rem;
	}
	p {
		margin: 0;
		font-size: 0.88rem;
		color: var(--muted);
	}
	.tag {
		margin-left: auto;
		font-size: 0.72rem;
		text-transform: uppercase;
		letter-spacing: 0.04em;
		color: var(--muted);
		border: 1px solid var(--line);
		border-radius: 999px;
		padding: 3px 9px;
		white-space: nowrap;
	}
</style>
