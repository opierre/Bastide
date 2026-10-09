"""Tests for the product version exposed by the backend package."""

import re
import tomllib
from pathlib import Path

from app import __version__

_PYPROJECT = Path(__file__).resolve().parents[1] / "pyproject.toml"


def test_version_is_not_empty() -> None:
    assert __version__
    assert __version__ != "0.0.0"


def test_version_matches_pyproject() -> None:
    declared = tomllib.loads(_PYPROJECT.read_text(encoding="utf-8"))["project"]["version"]

    assert __version__ == declared


def test_version_matches_frontend_pubspec() -> None:
    # Frontend and backend ship in one installer under one version; the build number
    # after `+` is the frontend's own and isn't compared.
    pubspec = _PYPROJECT.parents[1] / "frontend" / "pubspec.yaml"
    match = re.search(r"^version:\s*([^+\s]+)", pubspec.read_text(encoding="utf-8"), re.M)

    assert match is not None
    assert match.group(1) == __version__
