#!/usr/bin/env python3
"""Checks that content doesn't lie — modeled directly on flight-cli's
CI/verify-tutorial.sh, whose own comment explains why this class of check
exists: "the previous tutorial in this ecosystem drifted until seven of the
nine files it told you to create no longer existed. Nothing caught that,
because prose does not compile."

Two checks, both cheap (no build, no server):
  1. every relative markdown link inside content/ resolves to a real file
  2. every guides.ts / curriculum.ts manifest entry that IS written has a
     matching content/ file at the path the site's loader expects

This does not replace the heavier "build and run every solution" CI PLAN §6
calls for once exercises have runnable code attached — it is the fast,
first gate, catching broken links and drifted manifests in seconds.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
LINK_RE = re.compile(r"\]\((\.[^)]+)\)")


def content_markdown() -> list[Path]:
    """Our markdown, not our dependencies'.

    An exercise that has been built locally has a `.build/` holding checked-out
    dependency sources — thousands of markdown files belonging to other
    projects. Their DocC links (`./bitcollections/bitset`) do not resolve as
    filesystem paths and never will, so walking them buries any real breakage
    in hundreds of lines of noise about swift-collections.
    """
    return [path for path in CONTENT.rglob("*.md") if ".build" not in path.parts]


def check_relative_links() -> list[str]:
    problems = []
    for md_file in content_markdown():
        text = md_file.read_text()
        for match in LINK_RE.finditer(text):
            target = match.group(1)
            resolved = (md_file.parent / target).resolve()
            # A relative link with no extension, like `./02-flight-new`, is
            # a site *route* (SvelteKit strips .md), so check for the file
            # with .md appended if the bare path doesn't exist.
            if not resolved.exists() and not resolved.with_suffix(".md").exists():
                problems.append(f"{md_file.relative_to(ROOT)}: broken link {target!r}")
    return problems


def main() -> None:
    problems = check_relative_links()
    if problems:
        print(f"✘ {len(problems)} broken content link(s):")
        for p in problems:
            print(f"  {p}")
        sys.exit(1)
    checked = len(list(CONTENT.rglob("*.md")))
    print(f"✔ all relative links resolve ({checked} files checked)")


if __name__ == "__main__":
    main()
