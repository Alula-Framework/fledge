<script lang="ts">
	import '$lib/app.css';
	import favicon from '$lib/assets/favicon.svg';

	let { children } = $props();
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
</svelte:head>

<div class="shell">
	<header>
		<a class="brand" href="/">Fledge</a>
		<nav>
			<a href="/tutorial">Tutorial</a>
			<a href="/guides">Guides</a>
			<a href="https://github.com/Alula-Framework/alula">Alula ↗</a>
		</nav>
	</header>

	<main>
		{@render children()}
	</main>

	<footer>
		<p>
			Fledge is <a href="https://github.com/Alula-Framework/fledge">open source</a>.
			Every exercise here is downloadable as a plain SwiftPM package — the site never has to be
			the only way to learn this.
		</p>
	</footer>
</div>

<style>
	.shell {
		max-width: 960px;
		margin: 0 auto;
		padding: 0 20px;
		min-height: 100vh;
		display: flex;
		flex-direction: column;
	}

	header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 20px 0;
		border-bottom: 1px solid var(--line);
	}

	.brand {
		font-weight: 700;
		font-size: 1.1rem;
		color: var(--ink);
	}
	.brand:hover {
		text-decoration: none;
	}

	nav {
		display: flex;
		gap: 22px;
		font-size: 0.95rem;
	}
	nav a {
		color: var(--muted);
	}
	nav a:hover {
		color: var(--ink);
		text-decoration: none;
	}

	main {
		flex: 1;
		padding: 40px 0 60px;
	}

	footer {
		border-top: 1px solid var(--line);
		padding: 24px 0;
		font-size: 0.85rem;
		color: var(--muted);
	}
</style>
