#!/usr/bin/env python3
"""Write the release notes for a tag from the Conventional Commits since the previous tag.

  release_notes.py --tag v0.2.0 --repo opierre/FinStride --output notes.md

User-facing changes (feat, fix, perf) are listed by section; everything else (docs, build,
ci, ...) goes in a collapsed list. A `!` after the type or a `BREAKING CHANGE:` footer puts
the commit under "Breaking changes" as well. Merge commits are skipped: the commits they
bring in are listed on their own. With no earlier `v*` tag, the whole history counts, and
there are no breaking changes: nothing was released before, so nothing can break.

Runs on the runner's system Python; standard library only.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

HEADER = re.compile(r"^(?P<type>\w+)(?:\((?P<scope>[^)]+)\))?(?P<bang>!)?: (?P<subject>.+)$")

SECTIONS = {"feat": "New", "fix": "Fixes", "perf": "Performance"}

# Unit separator and record separator: they can't appear in a commit message.
FIELD, RECORD = "\x1f", "\x1e"


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], check=True, capture_output=True, text=True, encoding="utf-8"
    ).stdout


def previous_tag(tag: str) -> str | None:
    """The closest `v*` tag before `tag`, or None for the first release."""
    try:
        return git("describe", "--tags", "--abbrev=0", "--match", "v*", f"{tag}^").strip()
    except subprocess.CalledProcessError:
        return None


def commits(since: str | None, tag: str) -> list[tuple[str, str, str]]:
    """``(short sha, subject, body)`` of each non-merge commit after `since` up to `tag`."""
    span = f"{since}..{tag}" if since else tag
    log = git("log", "--no-merges", f"--format=%h{FIELD}%s{FIELD}%b{RECORD}", span)
    entries = []
    for record in log.split(RECORD):
        if record.strip():
            sha, subject, body = record.strip("\n").split(FIELD)
            entries.append((sha, subject, body))
    return entries


def line(sha: str, scope: str | None, subject: str) -> str:
    return f"- {f'**{scope}:** ' if scope else ''}{subject} ({sha})"


def notes(tag: str, repo: str) -> str:
    since = previous_tag(tag)
    breaking: list[str] = []
    sections: dict[str, list[str]] = {title: [] for title in SECTIONS.values()}
    other: list[str] = []
    for sha, subject, body in commits(since, tag):
        match = HEADER.match(subject)
        if match is None:
            other.append(f"- {subject} ({sha})")
            continue
        entry = line(sha, match["scope"], match["subject"])
        if since and (match["bang"] or "BREAKING CHANGE:" in body):
            breaking.append(entry)
        if match["type"] in SECTIONS:
            sections[SECTIONS[match["type"]]].append(entry)
        else:
            other.append(f"- {subject} ({sha})")

    guide = f"https://github.com/{repo}/blob/{tag}/docs/install.md"
    out = [
        f"Install: follow the [install guide]({guide}) ([français]({guide[:-3]}.fr.md)). "
        "The builds are not code-signed, so Windows and macOS warn on first launch; the guide "
        "shows how to continue and how to check the downloads against `SHA256SUMS`.",
        "",
    ]
    if breaking:
        out += ["## Breaking changes", "", *breaking, ""]
    for title, entries in sections.items():
        if entries:
            out += [f"## {title}", "", *entries, ""]
    if other:
        out += [
            "<details>",
            f"<summary>Other changes ({len(other)})</summary>",
            "",
            *other,
            "",
            "</details>",
            "",
        ]
    changes = f"compare/{since}...{tag}" if since else f"commits/{tag}"
    out.append(f"**Full changelog:** https://github.com/{repo}/{changes}")
    return "\n".join(out) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--tag", required=True, help="the tag being released, e.g. v0.2.0")
    parser.add_argument("--repo", required=True, help="owner/name on GitHub")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.write_text(notes(args.tag, args.repo), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
