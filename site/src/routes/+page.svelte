<script lang="ts">
	import { curriculum } from '$lib/curriculum';
</script>

<svelte:head>
	<title>Fledge</title>
</svelte:head>

<section class="hero">
	<h1>Learn Alula by building with it.</h1>
	<p class="lead">
		An interactive tutorial and reference for <a href="https://github.com/Alula-Framework/alula"
			>Alula</a
		>, <a href="https://github.com/Alula-Framework/hangar">Hangar</a>, and Changeset — from your
		first route to a working realtime app, and a plain-documentation track written at the level
		of detail Phoenix and Ecto readers expect.
	</p>
	<div class="cta">
		<a class="button" href="/tutorial/00-setup/01-install">Start the tutorial</a>
		<a class="button ghost" href="/guides">Browse the guides</a>
	</div>
</section>

<section>
	<h2>The tutorial, part by part</h2>
	<div class="parts">
		{#each curriculum as part}
			<a class="part" href="/tutorial/{part.slug}">
				<h3>{part.title}</h3>
				<p>{part.summary}</p>
			</a>
		{/each}
	</div>
</section>

<style>
	.hero {
		padding: 20px 0 10px;
	}
	.hero h1 {
		font-size: 2.4rem;
		letter-spacing: -0.02em;
		margin: 0 0 0.4em;
		max-width: 14ch;
	}
	.lead {
		font-size: 1.1rem;
		color: var(--muted);
		max-width: 60ch;
	}
	.cta {
		display: flex;
		gap: 12px;
		margin-top: 24px;
	}
	.button {
		display: inline-block;
		padding: 10px 18px;
		border-radius: 8px;
		background: var(--accent);
		color: var(--accent-ink);
		font-weight: 600;
	}
	.button:hover {
		text-decoration: none;
		opacity: 0.9;
	}
	.button.ghost {
		background: transparent;
		color: var(--ink);
		border: 1px solid var(--line);
	}

	section {
		margin-top: 48px;
	}
	section h2 {
		font-size: 1.3rem;
		margin-bottom: 16px;
	}

	.parts {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
		gap: 14px;
	}
	.part {
		display: block;
		padding: 16px 18px;
		border: 1px solid var(--line);
		border-radius: 10px;
		color: var(--ink);
		background: var(--panel);
	}
	.part:hover {
		text-decoration: none;
		border-color: var(--accent);
	}
	.part h3 {
		margin: 0 0 6px;
		font-size: 1rem;
	}
	.part p {
		margin: 0;
		font-size: 0.88rem;
		color: var(--muted);
	}
</style>
