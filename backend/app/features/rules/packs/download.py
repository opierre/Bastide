"""Downloading the logos a rule pack links to, when the user asks for it at import.

Only `https://upload.wikimedia.org/wikipedia/commons/` is ever contacted: the pack schema
refuses any other link, and every request here (redirects included) is checked again before it
is sent. The request carries nothing about the user: a fixed app `User-Agent`, no cookies, no
query added.

Wikimedia's robot policy asks for at most two requests at once and for a 429's `Retry-After` to
be waited out in full. Measured, the host also answers 429 once a client sends about 30 requests
within 10 seconds, asks for an 11 s wait, and counts the requests it refuses, so a burst ends in
long pauses and asking early only prolongs them. Requests are therefore spaced evenly, just under
that rate, which keeps the progress moving without ever being throttled; a 429 that still comes
holds every request of the import until its `Retry-After` has passed. A transient failure is
retried with backoff. An overall deadline keeps a throttled import from hanging: what is still
failing then is reported as a failed download.
"""

import asyncio
import logging
import random
import time
from collections.abc import Awaitable, Callable, Iterable
from typing import Protocol

import httpx

from app import __version__
from app.core.tls import tls_context
from app.features.rules.packs.schema import MAX_LOGO_BYTES, is_allowed_logo_url

logger = logging.getLogger(__name__)

_TIMEOUT = httpx.Timeout(10.0, connect=5.0)
#: Wikimedia's policy asks for an identifying agent; this names the app, never the user.
USER_AGENT = f"Bastide/{__version__} (+https://github.com/opierre/Bastide)"
#: Wikimedia redirects a renamed file once in a while; a chain longer than this is not a logo.
_MAX_REDIRECTS = 3
#: Downloads in flight at once: the most Wikimedia's robot policy allows.
CONCURRENCY = 2
#: The least time between two requests of one import, redirects and retries included. The host
#: throttles past about 30 requests in 10 seconds; this keeps a steady pace just under that.
REQUEST_INTERVAL_S = 0.35
#: Retries per URL after a 429, a 503 or a transient connect/read error. Never on other 4xx.
MAX_RETRIES = 3
#: Backoff before retry n (from 0) is `RETRY_BASE_S * 2**n` plus up to `RETRY_JITTER_S`.
RETRY_BASE_S = 1.0
RETRY_JITTER_S = 0.5
#: A `Retry-After` (in seconds) is honoured in full up to this; a longer one is cut to it, and
#: the deadline usually ends the download first. Wikimedia asks for about 11 s.
MAX_RETRY_AFTER_S = 30.0
#: The longest one import spends downloading logos, in seconds. A download still unfinished
#: then is abandoned and reported as failed; no retry starts if its wait would end past it.
DOWNLOAD_DEADLINE_S = 90.0

#: The statuses worth asking again: throttled, or temporarily unavailable.
_RETRY_STATUSES = frozenset({429, 503})

type Sleep = Callable[[float], Awaitable[None]]
#: Told about each URL as soon as its download settles, with its bytes or its failure.
type OnLogoResult = Callable[[str, bytes | LogoDownloadError], None]


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
        self,
        urls: Iterable[str],
        max_total_bytes: int,
        on_result: OnLogoResult | None = None,
    ) -> dict[str, bytes | LogoDownloadError]:
        """Download each distinct URL once; a failure is returned in its place, not raised.

        Each file is held to `MAX_LOGO_BYTES`, and all of them together to `max_total_bytes`:
        once that much has been received, the downloads still running or waiting fail with
        `LogoTooLargeError`. ``on_result``, when given, is called once per distinct URL as soon
        as it settles, which is what a background import reports its progress from.
        """
        ...


class HttpLogoFetcher:
    """`LogoFetcher` over HTTPS: allowed host only, retried, timed out and capped."""

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
            sleep: how to wait before a retry; tests pass one that only records.
            clock: monotonic seconds, read for the deadline.
            jitter: the random part of a backoff, in seconds.
        """
        self._transport = transport
        self._sleep = sleep
        self._clock = clock
        self._jitter = jitter

    async def fetch_all(
        self,
        urls: Iterable[str],
        max_total_bytes: int,
        on_result: OnLogoResult | None = None,
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
                pacer=_Pacer(self._sleep, self._clock),
                sleep=self._sleep,
                clock=self._clock,
                jitter=self._jitter,
            )

            async def settle(url: str) -> bytes | LogoDownloadError:
                async with gate:
                    try:
                        async with asyncio.timeout_at(hard_stop):
                            return await run.fetch(url)
                    except LogoDownloadError as exc:
                        return exc
                    except TimeoutError:
                        return LogoDownloadError("The logo downloads ran out of time.")

            async def one(url: str) -> bytes | LogoDownloadError:
                result = await settle(url)
                if on_result is not None:
                    on_result(url, result)
                return result

            results = await asyncio.gather(*(one(url) for url in distinct))
        return dict(zip(distinct, results, strict=True))


class _Pacer:
    """Spaces the requests of one import `REQUEST_INTERVAL_S` apart, and holds them after a 429.

    Each request takes the next free slot before it is sent. Taking a slot never yields, so on
    one event loop no two requests get the same one.
    """

    def __init__(self, sleep: Sleep, clock: Callable[[], float]) -> None:
        self._sleep = sleep
        self._clock = clock
        self._next = float("-inf")
        self._held_until = float("-inf")

    async def wait_turn(self) -> None:
        """Wait for this request's slot, then out any hold that began while it waited."""
        now = self._clock()
        start = max(now, self._next, self._held_until)
        self._next = start + REQUEST_INTERVAL_S
        if start > now:
            await self._sleep(start - now)
        held = self._held_until - self._clock()
        if held > 0:
            await self._sleep(held)

    def hold(self, seconds: float) -> None:
        """Send nothing more for ``seconds``: the host asked every request to wait."""
        self._held_until = max(self._held_until, self._clock() + seconds)


class _Run:
    """The state one `fetch_all` shares between its downloads: budget and deadline."""

    def __init__(
        self,
        http: httpx.AsyncClient,
        *,
        remaining: int,
        deadline: float,
        pacer: _Pacer,
        sleep: Sleep,
        clock: Callable[[], float],
        jitter: Callable[[], float],
    ) -> None:
        self._http = http
        self._remaining = remaining
        self._deadline = deadline
        self._pacer = pacer
        self._sleep = sleep
        self._clock = clock
        self._jitter = jitter

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
                if exc.retry_after is not None:
                    self._pacer.hold(wait)
                logger.debug("Logo download retry %d in %.2f s: %s", attempt + 1, wait, exc)
                await self._sleep(wait)
        raise AssertionError("unreachable")  # the loop always returns or raises

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
            await self._pacer.wait_turn()
            if self._clock() > self._deadline:
                raise LogoDownloadError("The logo downloads ran out of time.")
            sent = time.perf_counter()
            try:
                async with self._http.stream("GET", url) as response:
                    logger.debug(
                        "Logo download: HTTP %d after %.0f ms",
                        response.status_code,
                        (time.perf_counter() - sent) * 1000,
                    )
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
