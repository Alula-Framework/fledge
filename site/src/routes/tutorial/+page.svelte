<script lang="ts">
	import { curriculum } from '$lib/curriculum';
</script>

<svelte:head>
	<title>Tutorial — Fledge</title>
</svelte:head>

<h1>The tutorial</h1>
<p class="lead">
	Five parts, setup through advanced. Each exercise is one concept — most take five to fifteen
	minutes. Start at the top; later parts assume earlier ones.
</p>

<ol class="parts">
	{#each curriculum as part, i}
		<li>
			<a href="/tutorial/{part.slug}">
				<span class="num">{i}</span>
				<span>
					<h2>{part.title}</h2>
					<p>{part.summary}</p>
					<p class="meta">{part.exercises.length} exercises · runtime: {part.runtime}</p>
				</span>
			</a>
		</li>
	{/each}
</ol>

<style>
	.lead {
		color: var(--muted);
		max-width: 60ch;
	}
	.parts {
		list-style: none;
		padding: 0;
		margin: 32px 0 0;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}
	.parts a {
		display: flex;
		gap: 18px;
		align-items: flex-start;
		padding: 18px;
		border: 1px solid var(--line);
		border-radius: 10px;
		color: var(--ink);
	}
	.parts a:hover {
		text-decoration: none;
		border-color: var(--accent);
	}
	.num {
		font: 700 1.4rem var(--mono);
		color: var(--muted);
		min-width: 1.5em;
	}
	h2 {
		margin: 0 0 4px;
		font-size: 1.1rem;
	}
	p {
		margin: 0;
	}
	.meta {
		color: var(--muted);
		font-size: 0.82rem;
		margin-top: 6px;
		font-family: var(--mono);
	}
</style>
