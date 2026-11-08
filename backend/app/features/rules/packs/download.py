"""Downloading the logos a rule pack links to, when the user asks for it at import.

Only `https://upload.wikimedia.org/wikipedia/commons/` is ever contacted: the pack schema
refuses any other link, and every request here (redirects included) is checked again before it
is sent. The request carries nothing about the user: a fixed app `User-Agent`, no cookies, no
query added.

Wikimedia answers 429 to clients that ask too fast, and a national pack links dozens of logos,
so requests are paced, and a throttled or transiently failing one is retried with backoff. An
overall deadline keeps a throttled import from hanging: what is still failing then is reported
as a failed download.
"""

import asyncio
import random
import time
from collections.abc import Awaitable, Callable, Iterable
from typing import Protocol

import httpx

from app import __version__
from app.core.tls import tls_context
from app.features.rules.packs.schema import MAX_LOGO_BYTES, is_allowed_logo_url

_TIMEOUT = httpx.Timeout(10.0, connect=5.0)
#: Wikimedia's policy asks for an identifying agent; this names the app, never the user.
USER_AGENT = f"Bastide/{__version__} (+https://github.com/opierre/Bastide)"
#: Wikimedia redirects a renamed file once in a while; a chain longer than this is not a logo.
_MAX_REDIRECTS = 3
#: Downloads in flight at once. Kept low: the host throttles bursts.
CONCURRENCY = 2
#: Least time between two request starts (redirects and retries included), in seconds.
REQUEST_INTERVAL_S = 0.25
#: Retries per URL after a 429, a 503 or a transient connect/read error. Never on other 4xx.
MAX_RETRIES = 3
#: Backoff before retry n (from 0) is `RETRY_BASE_S * 2**n` plus up to `RETRY_JITTER_S`.
RETRY_BASE_S = 1.0
RETRY_JITTER_S = 0.5
#: A `Retry-After` (in seconds) is honoured up to this; a longer one is cut to it.
MAX_RETRY_AFTER_S = 10.0
#: The longest one import spends downloading logos, in seconds. A download still unfinished
#: then is abandoned and reported as failed; no retry starts if its wait would end past it.
DOWNLOAD_DEADLINE_S = 90.0

#: The statuses worth asking again: throttled, or temporarily unavailable.
_RETRY_STATUSES = frozenset({429, 503})

type Sleep = Callable[[float], Awaitable[None]]


class LogoDownloadError(Exception):
    """A logo could not be fetched: unreachable, slow, error status, bad redirect, too big."""


class LogoTooLargeError(LogoDownloadError):
    """The file is over the per-logo cap; the download was cut off there."""


class _Retryable(Exception):
    """A failure worth retrying, with the wait the server asked for, if it named one."""

    def __init__(self, reason: str, retry_after: float | None = None) -> None:
        super().__init__(reason)
        self.retry_after = retry_after


class LogoFetcher(Protocol):
    """Fetches the files a pack's linked logos point at."""

    async def fetch_all(
        self, urls: Iterable[str], max_total_bytes: int
    ) -> dict[str, bytes | LogoDownloadError]:
        """Download each distinct URL once; a failure is returned in its place, not raised.

        Each file is held to `MAX_LOGO_BYTES`, and all of them together to `max_total_bytes`:
        once that much has been received, the downloads still running or waiting fail with
        `LogoTooLargeError`.
        """
        ...


class HttpLogoFetcher:
    """`LogoFetcher` over HTTPS: allowed host only, paced, retried, timed out and capped."""

    def __init__(
        self,
        transport: httpx.AsyncBaseTransport | None = None,
        *,
        sleep: Sleep = asyncio.sleep,
        clock: Callable[[], float] = time.monotonic,
        jitter: Callable[[], float] = lambda: random.uniform(0.0, RETRY_JITTER_S),
    ) -> None:
        """Build a fetcher.

        Args:
            transport: injected in tests so nothing leaves the process.
            sleep: how to wait (pacing and backoff); tests pass one that only records.
            clock: monotonic seconds, read for pacing and the deadline.
            jitter: the random part of a backoff, in seconds.
        """
        self._transport = transport
        self._sleep = sleep
        self._clock = clock
        self._jitter = jitter

    async def fetch_all(
        self, urls: Iterable[str], max_total_bytes: int
    ) -> dict[str, bytes | LogoDownloadError]:
        distinct = list(dict.fromkeys(urls))
        if not distinct:
            return {}
        gate = asyncio.Semaphore(CONCURRENCY)
        # The hard stop runs on the event loop's own clock, so it holds even if a request
        # stalls between the soft checks made on `clock`.
        hard_stop = asyncio.get_running_loop().time() + DOWNLOAD_DEADLINE_S
        async with httpx.AsyncClient(
            transport=self._transport,
            timeout=_TIMEOUT,
            verify=tls_context(),
            follow_redirects=False,
            headers={"User-Agent": USER_AGENT},
        ) as http:
            run = _Run(
                http,
                remaining=max_total_bytes,
                deadline=self._clock() + DOWNLOAD_DEADLINE_S,
                sleep=self._sleep,
                clock=self._clock,
                jitter=self._jitter,
            )

            async def one(url: str) -> bytes | LogoDownloadError:
                async with gate:
                    try:
                        async with asyncio.timeout_at(hard_stop):
                            return await run.fetch(url)
                    except LogoDownloadError as exc:
                        return exc
                    except TimeoutError:
                        return LogoDownloadError("The logo downloads ran out of time.")

            results = await asyncio.gather(*(one(url) for url in distinct))
        return dict(zip(distinct, results, strict=True))


class _Run:
    """The state one `fetch_all` shares between its downloads: budget, pacing, deadline."""

    def __init__(
        self,
        http: httpx.AsyncClient,
        *,
        remaining: int,
        deadline: float,
        sleep: Sleep,
        clock: Callable[[], float],
        jitter: Callable[[], float],
    ) -> None:
        self._http = http
        self._remaining = remaining
        self._deadline = deadline
        self._sleep = sleep
        self._clock = clock
        self._jitter = jitter
        self._pace_lock = asyncio.Lock()
        self._last_start: float | None = None

    async def fetch(self, url: str) -> bytes:
        """Download one file, retrying a throttled or transient failure with backoff.

        Raises:
            LogoDownloadError: any failure once retries or the deadline run out.
            LogoTooLargeError: the body is over a size cap.
        """
        for attempt in range(MAX_RETRIES + 1):
            try:
                return await self._fetch_once(url)
            except _Retryable as exc:
                if attempt == MAX_RETRIES:
                    raise LogoDownloadError(f"Still failing after retries: {exc}") from exc
                if exc.retry_after is not None:
                    wait = min(exc.retry_after, MAX_RETRY_AFTER_S)
                else:
                    wait = RETRY_BASE_S * 2**attempt + self._jitter()
                if self._clock() + wait > self._deadline:
                    raise LogoDownloadError("The logo downloads ran out of time.") from exc
                await self._sleep(wait)
        raise AssertionError("unreachable")  # the loop always returns or raises

    async def _pace(self) -> None:
        """Wait until `REQUEST_INTERVAL_S` has passed since the previous request started."""
        async with self._pace_lock:
            now = self._clock()
            if self._last_start is not None:
                wait = self._last_start + REQUEST_INTERVAL_S - now
                if wait > 0:
                    await self._sleep(wait)
                    now = self._clock()
            if now > self._deadline:
                raise LogoDownloadError("The logo downloads ran out of time.")
            self._last_start = now

    async def _fetch_once(self, url: str) -> bytes:
        """Follow at most `_MAX_REDIRECTS` redirects, all on the allowed host, and read the file.

        Raises:
            _Retryable: a 429 or 503, or a transport error (connect, read, timeout).
            LogoDownloadError: any other failure, including a redirect off the allowed host.
            LogoTooLargeError: the body is over `MAX_LOGO_BYTES`, or the import's budget is spent.
        """
        for _ in range(_MAX_REDIRECTS + 1):
            if not is_allowed_logo_url(url):
                raise LogoDownloadError("The logo URL is not on the allowed host.")
            if self._remaining <= 0:
                raise LogoTooLargeError("The pack's logos are too large in all.")
            await self._pace()
            try:
                async with self._http.stream("GET", url) as response:
                    if response.is_redirect:
                        location = response.headers.get("location")
                        if location is None:
                            raise LogoDownloadError("A redirect without a location.")
                        url = str(response.url.join(location))
                        continue
                    if response.status_code in _RETRY_STATUSES:
                        raise _Retryable(
                            f"HTTP {response.status_code}.",
                            _retry_after(response.headers.get("retry-after")),
                        )
                    if response.status_code != 200:
                        raise LogoDownloadError(f"HTTP {response.status_code}.")
                    return await self._read(response)
            except httpx.TransportError as exc:
                raise _Retryable("The logo could not be downloaded.") from exc
            except httpx.HTTPError as exc:
                raise LogoDownloadError("The logo could not be downloaded.") from exc
        raise LogoDownloadError("Too many redirects.")

    async def _read(self, response: httpx.Response) -> bytes:
        """Read the body, cut off at the per-logo cap or once the import's budget is spent."""
        declared = response.headers.get("content-length")
        limit = min(MAX_LOGO_BYTES, self._remaining)
        if declared is not None and declared.isdigit() and int(declared) > limit:
            raise LogoTooLargeError("The logo is too large.")
        body = bytearray()
        async for chunk in response.aiter_bytes():
            body.extend(chunk)
            self._remaining -= len(chunk)
            if len(body) > MAX_LOGO_BYTES:
                raise LogoTooLargeError("The logo is too large.")
            if self._remaining < 0:
                raise LogoTooLargeError("The pack's logos are too large in all.")
        return bytes(body)


def _retry_after(value: str | None) -> float | None:
    """A `Retry-After` in seconds; `None` when absent or in its HTTP-date form."""
    if value is None or not value.strip().isdigit():
        return None
    return float(value.strip())


def get_logo_fetcher() -> LogoFetcher:
    """FastAPI dependency: the real fetcher. Tests override it with a mocked transport."""
    return HttpLogoFetcher()
