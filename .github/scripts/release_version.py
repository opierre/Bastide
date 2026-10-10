#!/usr/bin/env python3
"""Check that a release tag matches the version the source declares, and print that version.

  release_version.py v0.2.0          ->  0.2.0
  release_version.py v0.2.0-rc.1     ->  0.2.0-rc.1

The committed versions are the source of truth: `backend/pyproject.toml` and
`frontend/pubspec.yaml` must agree, and the tag must be `v<that version>`, optionally
followed by a pre-release suffix (`-rc.1`, `-beta.2`, ...) that names the packages only.
CI never rewrites the files: bump both, commit, then tag that commit.

With $GITHUB_OUTPUT set, also writes `version=<tag without v>` to it.
Runs on the runner's system Python; standard library only.
"""

from __future__ import annotations

import os
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

TAG = re.compile(r"^v(?P<core>\d+\.\d+\.\d+)(?P<pre>-[0-9A-Za-z.-]+)?$")


def backend_version() -> str:
    with (ROOT / "backend" / "pyproject.toml").open("rb") as file:
        return tomllib.load(file)["project"]["version"]


def frontend_version() -> str:
    """The build name of `pubspec.yaml`'s version, without its `+<build number>`."""
    text = (ROOT / "frontend" / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"^version:\s*([^\s+]+)", text, re.MULTILINE)
    if match is None:
        sys.exit("::error::frontend/pubspec.yaml declares no version")
    return match[1]


def main() -> int:
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} <tag>")
    tag = sys.argv[1]

    match = TAG.match(tag)
    if match is None:
        print(f"::error::{tag} is not a release tag: expected v<major>.<minor>.<patch>[-<pre>]")
        return 1

    backend, frontend = backend_version(), frontend_version()
    if backend != frontend:
        print(
            f"::error::backend/pyproject.toml declares {backend} but frontend/pubspec.yaml "
            f"declares {frontend}: they ship as one product version"
        )
        return 1
    if match["core"] != backend:
        print(
            f"::error::{tag} doesn't match the source version {backend}: bump "
            "backend/pyproject.toml and frontend/pubspec.yaml, or tag the right commit"
        )
        return 1

    version = tag.removeprefix("v")
    print(version)
    if output := os.environ.get("GITHUB_OUTPUT"):
        with open(output, "a", encoding="utf-8") as file:
            file.write(f"version={version}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
