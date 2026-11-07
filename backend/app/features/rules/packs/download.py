"""Downloading the logos a rule pack links to, when the user asks for it at import.

Only `https://upload.wikimedia.org/` is ever contacted: the pack schema refuses any other
link, and every request here (redirects included) is checked again before it is sent. The
request carries nothing about the user: a fixed app `User-Agent`, no cookies, no query added.
"""

import asyncio
from collections.abc import Iterable
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
#: Downloads in flight at once: a large pack goes faster without hammering the host.
_CONCURRENCY = 4


class LogoDownloadError(Exception):
    """A logo could not be fetched: unreachable, slow, error status, bad redirect, too big."""


class LogoTooLargeError(LogoDownloadError):
    """The file is over the per-logo cap; the download was cut off there."""


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


class _Budget:
    """Bytes the downloads of one import may still receive, shared between them."""

    def __init__(self, remaining: int) -> None:
        self.remaining = remaining


class HttpLogoFetcher:
    """`LogoFetcher` over HTTPS, held to the allowed host, a timeout and size caps."""

    def __init__(self, transport: httpx.AsyncBaseTransport | None = None) -> None:
        """Build a fetcher; `transport` is injected in tests so nothing leaves the process."""
        self._transport = transport

    async def fetch_all(
        self, urls: Iterable[str], max_total_bytes: int
    ) -> dict[str, bytes | LogoDownloadError]:
        distinct = list(dict.fromkeys(urls))
        if not distinct:
            return {}
        budget = _Budget(max_total_bytes)
        gate = asyncio.Semaphore(_CONCURRENCY)
        async with httpx.AsyncClient(
            transport=self._transport,
            timeout=_TIMEOUT,
            verify=tls_context(),
            follow_redirects=False,
            headers={"User-Agent": USER_AGENT},
        ) as http:

            async def one(url: str) -> bytes | LogoDownloadError:
                async with gate:
                    try:
                        return await _fetch(http, url, budget)
                    except LogoDownloadError as exc:
                        return exc

            results = await asyncio.gather(*(one(url) for url in distinct))
        return dict(zip(distinct, results, strict=True))


async def _fetch(http: httpx.AsyncClient, url: str, budget: _Budget) -> bytes:
    """Follow at most `_MAX_REDIRECTS` redirects, all on the allowed host, and read the file.

    Raises:
        LogoDownloadError: any failure, including a redirect off the allowed host.
        LogoTooLargeError: the body is over `MAX_LOGO_BYTES`, or the import's budget is spent.
    """
    for _ in range(_MAX_REDIRECTS + 1):
        if not is_allowed_logo_url(url):
            raise LogoDownloadError("The logo URL is not on the allowed host.")
        if budget.remaining <= 0:
            raise LogoTooLargeError("The pack's logos are too large in all.")
        try:
            async with http.stream("GET", url) as response:
                if response.is_redirect:
                    location = response.headers.get("location")
                    if location is None:
                        raise LogoDownloadError("A redirect without a location.")
                    url = str(response.url.join(location))
                    continue
                if response.status_code != 200:
                    raise LogoDownloadError(f"HTTP {response.status_code}.")
                declared = response.headers.get("content-length")
                limit = min(MAX_LOGO_BYTES, budget.remaining)
                if declared is not None and declared.isdigit() and int(declared) > limit:
                    raise LogoTooLargeError("The logo is too large.")
                body = bytearray()
                async for chunk in response.aiter_bytes():
                    body.extend(chunk)
                    budget.remaining -= len(chunk)
                    if len(body) > MAX_LOGO_BYTES:
                        raise LogoTooLargeError("The logo is too large.")
                    if budget.remaining < 0:
                        raise LogoTooLargeError("The pack's logos are too large in all.")
                return bytes(body)
        except httpx.HTTPError as exc:
            raise LogoDownloadError("The logo could not be downloaded.") from exc
    raise LogoDownloadError("Too many redirects.")


def get_logo_fetcher() -> LogoFetcher:
    """FastAPI dependency: the real fetcher. Tests override it with a mocked transport."""
    return HttpLogoFetcher()
