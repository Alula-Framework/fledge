#!/usr/bin/env python3
"""Build — and where possible run — every exercise's real code.

This is the guarantee that survived dropping the app tier (see STATUS.md).
The interactive runner pool was expensive to serve; *compiling and running
the exercises* is cheap, and it was the compiling and running, not the
serving, that actually caught bugs: a `ResponseEncodable` error that had
been wrong in published prose since M0, an exercise whose payoff nothing
could observe, and a registration bug in flight-cli's own `basics`
template. None of those needed a browser.

Two tiers, two shapes:

* **snippet** — `content/tutorial/02-data/<slug>.swift` is one file that
  drops into the runner's prebuilt workspace as `Sources/exercise/main.swift`.
  Ones that call `makeRepo()` need a database; with `DATABASE_URL` set they
  are *run*, not merely built, because "it compiles" says nothing about
  whether the query was right.
* **app** — `content/tutorial/<part>/<slug>/` holds `meta.json` plus
  `app-a`/`app-b` diffs against a named `flight new` template (PLAN §6).
  `app-b` is the solution and must build. `app-a` is the starting state and
  is deliberately allowed not to — it is frequently an empty file.

Both tiers reuse one workspace across every exercise so dependencies
compile once. The workspace is reset from a pristine copy between
exercises (`.build` deliberately preserved), because exercises reuse type
names — three of them define `IssueController` — and a leftover file from
the previous one would either collide or, worse, silently satisfy a
reference the exercise under test should have failed on.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SNIPPET_DIR = REPO / "content" / "tutorial" / "02-data"
TUTORIAL_DIR = REPO / "content" / "tutorial"
SNIPPET_WORKSPACE = REPO / "runner" / "workspace"

# Exit non-zero on the first failure would hide how much else is broken;
# everything runs and the summary reports the total.
failures: list[str] = []


def run(cmd: list[str], cwd: Path, env: dict | None = None, timeout: int = 900):
    return subprocess.run(
        cmd, cwd=cwd, env=env, timeout=timeout,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)


def report(name: str, ok: bool, detail: str = "") -> bool:
    print(f"  {'PASS' if ok else 'FAIL'}  {name}")
    if not ok:
        failures.append(name)
        for line in detail.strip().splitlines()[-25:]:
            print(f"        {line}")
    return ok


def reset_workspace(pristine: Path, work: Path):
    """Restore `work` to `pristine`, keeping the warm `.build`."""
    subprocess.run(
        ["rsync", "-a", "--delete", "--exclude", ".build", "--exclude", ".home",
         f"{pristine}/", f"{work}/"],
        check=True)


def check_snippets(database_url: str | None) -> None:
    snippets = sorted(SNIPPET_DIR.glob("*.swift"))
    if not snippets:
        print("no snippet exercises found")
        return
    print(f"\nsnippet tier — {len(snippets)} exercises"
          + ("" if database_url else "  (no DATABASE_URL: building only)"))

    with tempfile.TemporaryDirectory() as tmp:
        pristine = Path(tmp) / "pristine"
        work = Path(tmp) / "work"
        # Source only. A compiled `.build` cannot be relocated — Clang bakes
        # the absolute module-cache path into its .pcm files, so a copied one
        # fails with "missing required module 'SwiftShims'" rather than
        # rebuilding. The runner's Dockerfile documents the same trap for the
        # same reason; this script hit it too, which is a fair sign it is
        # worth restating rather than assuming anyone remembers.
        ignore = shutil.ignore_patterns(".build", ".home")
        shutil.copytree(SNIPPET_WORKSPACE, pristine, ignore=ignore)
        shutil.copytree(SNIPPET_WORKSPACE, work, ignore=ignore)

        for snippet in snippets:
            reset_workspace(pristine, work)
            (work / "Sources" / "exercise" / "main.swift").write_text(
                snippet.read_text())

            built = run(["swift", "build"], cwd=work)
            if not report(f"{snippet.name} (build)", built.returncode == 0, built.stdout):
                continue

            # Running is the point. A snippet that compiles can still print
            # the wrong thing, or throw against real data — which is exactly
            # the class of bug this suite exists to catch.
            needs_db = "makeRepo()" in snippet.read_text()
            if needs_db and not database_url:
                print(f"        (skipped run: needs a database)")
                continue
            env = dict(os.environ)
            if database_url:
                env["DATABASE_URL"] = database_url
            ran = run([str(work / ".build" / "debug" / "exercise")], cwd=work,
                      env=env, timeout=120)
            report(f"{snippet.name} (run)", ran.returncode == 0, ran.stdout)


def check_app_exercises(templates: Path) -> None:
    exercises = sorted(p.parent for p in TUTORIAL_DIR.glob("*/*/meta.json"))
    if not exercises:
        print("no app-tier exercises found")
        return
    print(f"\napp tier — {len(exercises)} exercises  (templates: {templates})")

    # Group by template so each one's dependencies resolve once.
    by_template: dict[str, list[Path]] = {}
    for exercise in exercises:
        meta = json.loads((exercise / "meta.json").read_text())
        by_template.setdefault(meta.get("template", "skeleton"), []).append(exercise)

    for template_name, group in sorted(by_template.items()):
        source = templates / template_name
        if not source.is_dir():
            report(f"template '{template_name}'", False,
                   f"not found at {source} — pass --templates or check out flight-cli")
            continue

        with tempfile.TemporaryDirectory() as tmp:
            pristine = Path(tmp) / "pristine"
            work = Path(tmp) / "work"
            ignore = shutil.ignore_patterns(".build", ".home")
            shutil.copytree(source, pristine, ignore=ignore)
            shutil.copytree(source, work, ignore=ignore)

            for exercise in group:
                reset_workspace(pristine, work)
                solution = exercise / "app-b"
                if not solution.is_dir():
                    report(f"{exercise.name}", False, "no app-b/ to build")
                    continue
                # Overlay the solution over the template, exactly as a
                # learner's edits would land on their own project.
                shutil.copytree(solution, work, dirs_exist_ok=True)

                # Bump the mtime of every overlaid source. rsync and copytree
                # both preserve the files' git-checkout mtimes, which can be
                # *older* than an object file the warm `.build` compiled for a
                # previous exercise — and several exercises define the same
                # type (three define `IssueController`, with different routes).
                # SwiftPM's incremental check is mtime-based, so a stale-but-
                # newer `.o` gets reused and the app links against the previous
                # exercise's macro-generated `_flightRoute_*` symbols, failing
                # with an undefined-reference error for a symbol the *current*
                # source would have produced. Touching forces a recompile of
                # whatever changed while leaving the expensive dependency build
                # warm.
                for path in work.rglob("*"):
                    if ".build" in path.parts or path.is_dir():
                        continue
                    if path.suffix in {".swift", ".yaml", ".yml", ".json"} or path.name == "Package.swift":
                        path.touch()

                # An exercise whose solution lives in Tests/ needs the test
                # target compiled — plain `swift build` skips it entirely,
                # so the whole file would go unchecked while still reporting
                # a pass.
                touches_tests = (solution / "Tests").is_dir()
                command = ["swift", "build"] + (["--build-tests"] if touches_tests else [])
                built = run(command, cwd=work)
                # Named by part too: several parts now use the same slug
                # numbering, so "01-..." alone would be ambiguous.
                label = f"{exercise.parent.name}/{exercise.name}"
                report(f"{label} (app-b builds)", built.returncode == 0, built.stdout)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--templates", type=Path,
        default=REPO.parent / "flight-cli" / "templates",
        help="flight-cli's templates/ directory (default: a sibling checkout)")
    parser.add_argument("--tier", choices=["snippet", "app", "all"], default="all")
    parser.add_argument(
        "--database-url", default=os.environ.get("DATABASE_URL"),
        help="Postgres for db-tier snippets; without it they build but don't run")
    args = parser.parse_args()

    if args.tier in ("snippet", "all"):
        check_snippets(args.database_url)
    if args.tier in ("app", "all"):
        check_app_exercises(args.templates)

    print()
    if failures:
        print(f"{len(failures)} failed:")
        for name in failures:
            print(f"  - {name}")
        return 1
    print("all exercises built" + (" and ran" if args.database_url else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
