<script lang="ts">
	import { guidesByCategory } from '$lib/guides';
	const categories = guidesByCategory();
</script>

<svelte:head>
	<title>Guides — Fledge</title>
</svelte:head>

<h1>Guides</h1>
<p class="lead">
	Narrative reference, one page per topic — the plain-documentation track, separate from the
	interactive tutorial. Written to be read start to finish, in the style of the Phoenix and Ecto
	guides.
</p>

{#each [...categories] as [category, list]}
	<section>
		<h2>{category}</h2>
		<ul>
			{#each list as guide}
				<li>
					<a href="/guides/{guide.slug}">{guide.title}</a>
					<span class="desc">{guide.description}</span>
				</li>
			{/each}
		</ul>
	</section>
{/each}

<style>
	.lead {
		color: var(--muted);
		max-width: 60ch;
	}
	section {
		margin-top: 32px;
	}
	section h2 {
		font-size: 1rem;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: var(--muted);
		border-bottom: 1px solid var(--line);
		padding-bottom: 8px;
	}
	ul {
		list-style: none;
		padding: 0;
		margin: 0;
	}
	li {
		padding: 12px 0;
		border-bottom: 1px solid var(--line);
	}
	li a {
		font-weight: 600;
		display: block;
	}
	.desc {
		display: block;
		color: var(--muted);
		font-size: 0.9rem;
		margin-top: 2px;
	}
</style>
