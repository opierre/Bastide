"""Tests for reading the newest release from GitHub and for version ordering."""

import asyncio
from collections.abc import Callable, Coroutine
from typing import Any

import httpx
import pytest

from app.features.updates.releases import (
    LATEST_RELEASE_URL,
    GitHubReleases,
    ReleaseCheckFailed,
    is_newer,
)


def run[T](coro: Coroutine[Any, Any, T]) -> T:
    """Drive one coroutine to completion (avoids depending on an async pytest plugin)."""
    return asyncio.run(coro)


def _releases(
    handler: Callable[[httpx.Request], httpx.Response],
) -> tuple[GitHubReleases, list[httpx.Request]]:
    seen: list[httpx.Request] = []

    def record(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return handler(request)

    return GitHubReleases(transport=httpx.MockTransport(record)), seen


def test_the_latest_tag_is_read_without_its_v() -> None:
    releases, _ = _releases(lambda _: httpx.Response(200, json={"tag_name": "v0.2.0"}))

    assert run(releases.latest_version()) == "0.2.0"


def test_the_request_carries_nothing_about_the_user() -> None:
    releases, seen = _releases(lambda _: httpx.Response(200, json={"tag_name": "v0.2.0"}))

    run(releases.latest_version())

    (request,) = seen
    assert request.method == "GET"
    assert str(request.url) == LATEST_RELEASE_URL
    assert request.url.query == b""
    # No version in the user agent, no cookies, no auth.
    assert request.headers["user-agent"] == "Bastide"
    assert "cookie" not in request.headers
    assert "authorization" not in request.headers


def test_no_published_release_is_no_version() -> None:
    releases, _ = _releases(lambda _: httpx.Response(404, json={"message": "Not Found"}))

    assert run(releases.latest_version()) is None


@pytest.mark.parametrize(
    "response",
    [
        httpx.Response(500),
        httpx.Response(403, json={"message": "API rate limit exceeded"}),
        httpx.Response(200, text="not json"),
        httpx.Response(200, json={"name": "no tag"}),
        httpx.Response(200, json={"tag_name": "nightly"}),
        httpx.Response(200, json=["not", "an", "object"]),
    ],
)
def test_an_unusable_answer_fails_the_check(response: httpx.Response) -> None:
    releases, _ = _releases(lambda _: response)

    with pytest.raises(ReleaseCheckFailed):
        run(releases.latest_version())


def test_being_offline_fails_the_check() -> None:
    def refuse(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("no network", request=request)

    releases, _ = _releases(refuse)

    with pytest.raises(ReleaseCheckFailed):
        run(releases.latest_version())


@pytest.mark.parametrize(
    ("candidate", "current"),
    [
        ("0.2.0", "0.1.0"),
        ("0.1.1", "0.1.0"),
        ("1.0.0", "0.9.9"),
        ("0.10.0", "0.9.0"),
        ("1.0.0", "1.0.0-rc.1"),
        ("1.0.0-rc.2", "1.0.0-rc.1"),
        ("1.0.0-rc.10", "1.0.0-rc.2"),
        ("1.0.0-rc.1", "1.0.0-beta.3"),
        ("v0.2.0", "0.1.0"),
    ],
)
def test_newer_versions(candidate: str, current: str) -> None:
    assert is_newer(candidate, current)
    assert not is_newer(current, candidate)


@pytest.mark.parametrize(
    ("candidate", "current"),
    [("0.1.0", "0.1.0"), ("0.1.0", "0.2.0"), ("garbage", "0.1.0"), ("0.2.0", "garbage")],
)
def test_not_newer(candidate: str, current: str) -> None:
    assert not is_newer(candidate, current)
