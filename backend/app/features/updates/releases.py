"""Asking GitHub which Bastide release is the newest, and comparing versions.

This is the one request in the app that leaves the machine, so it carries nothing about the
user: a fixed `User-Agent` without the version, no cookies, no query string. It runs only
when the user has turned the update check on (`user_settings.update_check_enabled`).
"""

import re
from typing import Protocol

import httpx

from app.core.tls import tls_context

#: The repository whose GitHub Releases are the update channel.
RELEASES_REPO = "opierre/Bastide"
LATEST_RELEASE_URL = f"https://api.github.com/repos/{RELEASES_REPO}/releases/latest"

_TIMEOUT = httpx.Timeout(10.0, connect=5.0)
_HEADERS = {
    "Accept": "application/vnd.github+json",
    # GitHub rejects requests without one; the version would tell it more than it needs.
    "User-Agent": "Bastide",
}

# `v1.2.3` or `1.2.3`, with an optional `-rc.1` style pre-release, as the release workflow
# tags them (.github/scripts/release_version.py).
_VERSION = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$")


class ReleaseCheckFailed(Exception):
    """GitHub could not be reached, or answered with something that is not a release."""


class ReleaseSource(Protocol):
    """Where the newest published release comes from."""

    async def latest_version(self) -> str | None:
        """The newest published release's version (`1.2.3`), or `None` if there is none.

        Raises:
            ReleaseCheckFailed: no answer, or not one that names a release.
        """
        ...


class GitHubReleases:
    """`GET /repos/<repo>/releases/latest`, which skips drafts and pre-releases."""

    def __init__(self, transport: httpx.AsyncBaseTransport | None = None) -> None:
        self._transport = transport

    async def latest_version(self) -> str | None:
        try:
            async with httpx.AsyncClient(
                transport=self._transport, timeout=_TIMEOUT, verify=tls_context()
            ) as http:
                response = await http.get(LATEST_RELEASE_URL, headers=_HEADERS)
        except httpx.HTTPError as exc:
            raise ReleaseCheckFailed("GitHub could not be reached.") from exc

        # No published release yet: nothing to update to, not a failure.
        if response.status_code == 404:
            return None
        if response.status_code >= 400:
            raise ReleaseCheckFailed(f"GitHub answered HTTP {response.status_code}.")
        try:
            tag = response.json()["tag_name"]
        except (ValueError, KeyError, TypeError) as exc:
            raise ReleaseCheckFailed("GitHub's answer names no release.") from exc
        if not isinstance(tag, str) or _VERSION.match(tag) is None:
            raise ReleaseCheckFailed("The latest release's tag is not a version.")
        return tag.removeprefix("v")


def is_newer(candidate: str, current: str) -> bool:
    """Whether `candidate` comes after `current` in semantic-version order.

    A pre-release sorts before its release (`1.0.0-rc.1` < `1.0.0`), so someone on a release
    candidate is offered the final release. A version that doesn't parse is never newer.
    """
    left, right = _key(candidate), _key(current)
    return left is not None and right is not None and left > right


# (kind, number, text): numeric identifiers are (0, n, ""), alphanumeric ones (1, 0, s).
type _Identifier = tuple[int, int, str]


def _key(version: str) -> tuple[tuple[int, int, int], int, tuple[_Identifier, ...]] | None:
    match = _VERSION.match(version)
    if match is None:
        return None
    core = (int(match[1]), int(match[2]), int(match[3]))
    if match[4] is None:
        # Sorts after every pre-release of the same core version.
        return core, 1, ()
    # Numeric identifiers compare as numbers and before alphanumeric ones (semver §11).
    identifiers = tuple(
        (0, int(part), "") if part.isdigit() else (1, 0, part) for part in match[4].split(".")
    )
    return core, 0, identifiers
