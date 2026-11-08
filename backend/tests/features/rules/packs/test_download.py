"""Tests for the logo downloader's pacing, retries and deadline, on a fake clock.

`httpx.MockTransport` stands in for the network and the fetcher's `sleep` only advances a fake
clock, so nothing leaves the process and no test actually waits.
"""

import asyncio
from collections.abc import Callable

import httpx
import pytest

from app.features.rules.packs import download as download_module
from app.features.rules.packs.download import (
    MAX_RETRIES,
    MAX_RETRY_AFTER_S,
    REQUEST_INTERVAL_S,
    RETRY_BASE_S,
    HttpLogoFetcher,
    LogoDownloadError,
)

LOGO_URL = "https://upload.wikimedia.org/wikipedia/commons/a/ab/Epicerie_Lune_logo.png"
OTHER_LOGO_URL = "https://upload.wikimedia.org/wikipedia/commons/c/cd/Velo_Rapide_logo.png"
PICTURE = b"\x89PNG fake picture bytes"

type Handler = Callable[[httpx.Request], httpx.Response]


class _Clock:
    """A fake monotonic clock that `sleep` advances, recording every wait."""

    def __init__(self) -> None:
        self.now = 1000.0
        self.sleeps: list[float] = []

    def __call__(self) -> float:
        return self.now

    async def sleep(self, seconds: float) -> None:
        self.sleeps.append(seconds)
        self.now += seconds


class _Server:
    """Answers each URL from a queue of responses, recording when each request arrived."""

    def __init__(self, clock: _Clock) -> None:
        self.clock = clock
        self.queues: dict[str, list[Handler]] = {}
        self.arrivals: list[tuple[str, float]] = []

    def answer(self, url: str, *handlers: Handler) -> None:
        self.queues[url] = list(handlers)

    def handle(self, request: httpx.Request) -> httpx.Response:
        url = str(request.url)
        self.arrivals.append((url, self.clock.now))
        queue = self.queues[url]
        handler = queue.pop(0) if len(queue) > 1 else queue[0]
        return handler(request)


def _ok(_: httpx.Request) -> httpx.Response:
    return httpx.Response(200, content=PICTURE)


def _status(code: int, **headers: str) -> Handler:
    return lambda _: httpx.Response(code, headers=headers)


def _connect_error(request: httpx.Request) -> httpx.Response:
    raise httpx.ConnectError("unreachable", request=request)


@pytest.fixture
def clock() -> _Clock:
    return _Clock()


@pytest.fixture
def server(clock: _Clock) -> _Server:
    return _Server(clock)


def _fetch(server: _Server, clock: _Clock, *urls: str) -> dict[str, bytes | LogoDownloadError]:
    fetcher = HttpLogoFetcher(
        httpx.MockTransport(server.handle), sleep=clock.sleep, clock=clock, jitter=lambda: 0.0
    )
    return asyncio.run(fetcher.fetch_all(urls, 10_000_000))


def test_a_429_then_200_succeeds(server: _Server, clock: _Clock) -> None:
    server.answer(LOGO_URL, _status(429), _ok)

    result = _fetch(server, clock, LOGO_URL)

    assert result[LOGO_URL] == PICTURE
    assert len(server.arrivals) == 2
    assert clock.sleeps == [RETRY_BASE_S]


def test_a_503_and_a_connect_error_are_retried_with_exponential_backoff(
    server: _Server, clock: _Clock
) -> None:
    server.answer(LOGO_URL, _status(503), _connect_error, _ok)

    result = _fetch(server, clock, LOGO_URL)

    assert result[LOGO_URL] == PICTURE
    assert clock.sleeps == [RETRY_BASE_S, RETRY_BASE_S * 2]


def test_retry_after_is_honoured(server: _Server, clock: _Clock) -> None:
    server.answer(LOGO_URL, _status(429, **{"retry-after": "3"}), _ok)

    result = _fetch(server, clock, LOGO_URL)

    assert result[LOGO_URL] == PICTURE
    assert clock.sleeps == [3.0]


def test_a_long_retry_after_is_capped(server: _Server, clock: _Clock) -> None:
    server.answer(LOGO_URL, _status(429, **{"retry-after": "3600"}), _ok)

    _fetch(server, clock, LOGO_URL)

    assert clock.sleeps == [MAX_RETRY_AFTER_S]


def test_a_retry_after_date_falls_back_to_backoff(server: _Server, clock: _Clock) -> None:
    server.answer(LOGO_URL, _status(429, **{"retry-after": "Wed, 21 Oct 2026 07:28:00 GMT"}), _ok)

    _fetch(server, clock, LOGO_URL)

    assert clock.sleeps == [RETRY_BASE_S]


def test_exhausted_retries_end_as_a_failed_download(server: _Server, clock: _Clock) -> None:
    server.answer(LOGO_URL, _status(429))

    result = _fetch(server, clock, LOGO_URL)

    assert isinstance(result[LOGO_URL], LogoDownloadError)
    assert len(server.arrivals) == MAX_RETRIES + 1
    assert clock.sleeps == [RETRY_BASE_S * 2**n for n in range(MAX_RETRIES)]


@pytest.mark.parametrize("status", [400, 403, 404, 410, 500])
def test_other_error_statuses_are_not_retried(server: _Server, clock: _Clock, status: int) -> None:
    server.answer(LOGO_URL, _status(status))

    result = _fetch(server, clock, LOGO_URL)

    assert isinstance(result[LOGO_URL], LogoDownloadError)
    assert len(server.arrivals) == 1
    assert clock.sleeps == []


def test_requests_are_paced(server: _Server, clock: _Clock) -> None:
    urls = [f"{LOGO_URL[:-4]}_{n}.png" for n in range(5)]
    for url in urls:
        server.answer(url, _ok)

    result = _fetch(server, clock, *urls)

    assert all(result[url] == PICTURE for url in urls)
    starts = [at for _, at in server.arrivals]
    assert len(starts) == 5
    assert all(b - a >= REQUEST_INTERVAL_S for a, b in zip(starts, starts[1:], strict=False))


def test_no_retry_starts_past_the_deadline(
    server: _Server, clock: _Clock, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(download_module, "DOWNLOAD_DEADLINE_S", 2.5)
    server.answer(LOGO_URL, _status(503))
    server.answer(OTHER_LOGO_URL, _ok)

    result = _fetch(server, clock, LOGO_URL, OTHER_LOGO_URL)

    # 1 s, then 2 s would end past the 2.5 s deadline: the second retry never starts.
    assert isinstance(result[LOGO_URL], LogoDownloadError)
    assert [url for url, _ in server.arrivals].count(LOGO_URL) == 2
    assert result[OTHER_LOGO_URL] == PICTURE
