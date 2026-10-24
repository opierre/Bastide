"""Tests for the product version exposed by the backend package."""

import re
import tomllib
from pathlib import Path

from packaging.version import Version

from app import __version__

_PYPROJECT = Path(__file__).resolve().parents[1] / "pyproject.toml"


def test_version_is_not_empty() -> None:
    assert __version__
    assert __version__ != "0.0.0"


def test_version_matches_pyproject() -> None:
    # The package metadata holds the PEP 440 form, which can be spelled differently from what
    # pyproject declares (`0.1.1-dev.0` installs as `0.1.1.dev0`): compare versions, not text.
    declared = tomllib.loads(_PYPROJECT.read_text(encoding="utf-8"))["project"]["version"]

    assert Version(__version__) == Version(declared)


def test_version_matches_frontend_pubspec() -> None:
    # Frontend and backend ship in one installer under one version; the build number
    # after `+` is the frontend's own and isn't compared. The pubspec spells a pre-release
    # the SemVer way (`0.1.1-dev.0`), the backend the PEP 440 way (`0.1.1.dev0`).
    pubspec = _PYPROJECT.parents[1] / "frontend" / "pubspec.yaml"
    match = re.search(r"^version:\s*([^+\s]+)", pubspec.read_text(encoding="utf-8"), re.M)

    assert match is not None
    assert Version(match.group(1)) == Version(__version__)
