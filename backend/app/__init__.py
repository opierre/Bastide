"""Bastide backend."""

from importlib.metadata import PackageNotFoundError, version

try:
    # One product version for the whole app, declared once in pyproject.toml.
    __version__ = version("bastide-backend")
except PackageNotFoundError:  # running from a source tree that was never installed
    __version__ = "0.0.0"
