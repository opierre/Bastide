"""Tests for the logos a rule pack brings: both forms, the host allowlist, caps and downloads.

Every download goes through `httpx.MockTransport`: nothing leaves the process.
"""

import base64
import io
from collections.abc import Callable
from typing import Any

import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from PIL import Image

from app.features.rules.packs import download as download_module
from app.features.rules.packs import schema as schema_module
from app.features.rules.packs import service as service_module
from app.features.rules.packs.download import HttpLogoFetcher, get_logo_fetcher
from tests.features.rules.packs.helpers import (
    GROCERIES,
    TRANSIT,
    category_id_for_key,
    entry,
    import_pack,
    pack,
    preview,
)
from tests.features.rules.test_rules import _create_rule, _register

LOGO_URL = "https://upload.wikimedia.org/wikipedia/commons/a/ab/Epicerie_Lune_logo.png"
OTHER_LOGO_URL = "https://upload.wikimedia.org/wikipedia/commons/c/cd/Velo_Rapide_logo.png"


def _picture(fmt: str = "PNG", colour: tuple[int, int, int] = (200, 40, 40)) -> bytes:
    output = io.BytesIO()
    Image.new("RGB", (300, 200), colour).save(output, format=fmt)
    return output.getvalue()


def _embedded(data: bytes | None = None) -> dict[str, str]:
    return {"data": base64.b64encode(data if data is not None else _picture()).decode()}


def _linked(url: str = LOGO_URL, **overrides: str) -> dict[str, str]:
    return {
        "url": url,
        "license": "CC0",
        "source": "https://commons.wikimedia.org/wiki/File:Epicerie_Lune_logo.png",
        **overrides,
    }


class _Web:
    """A fake web behind `httpx.MockTransport`, recording every request the import makes."""

    def __init__(self, app: FastAPI) -> None:
        self.requests: list[httpx.Request] = []
        self.routes: dict[str, Callable[[httpx.Request], httpx.Response]] = {}
        self.sleeps: list[float] = []
        transport = httpx.MockTransport(self._handle)
        # Backoff records its waits instead of sleeping (see test_download.py).
        app.dependency_overrides[get_logo_fetcher] = lambda: HttpLogoFetcher(
            transport, sleep=self._sleep
        )

    async def _sleep(self, seconds: float) -> None:
        self.sleeps.append(seconds)

    def serve(self, url: str, body: bytes | None = None, status: int = 200, **headers: str):
        self.routes[url] = lambda _: httpx.Response(
            status, content=body if body is not None else _picture(), headers=headers
        )

    def _handle(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        route = self.routes.get(str(request.url))
        if route is None:
            raise httpx.ConnectError("unreachable", request=request)
        return route(request)


@pytest.fixture
def web(app: FastAPI, client: TestClient) -> _Web:
    return _Web(app)


def _rules(client: TestClient, headers: dict[str, str]) -> dict[str, dict[str, Any]]:
    return {rule["pattern"]: rule for rule in client.get("/api/v1/rules", headers=headers).json()}


def _logo(client: TestClient, headers: dict[str, str], rule_id: str) -> bytes | None:
    response = client.get(f"/api/v1/rules/{rule_id}/logo", headers=headers)
    return response.content if response.status_code == 200 else None


# --- the two forms -------------------------------------------------------------------------


def test_preview_counts_embedded_and_linked_logos(client: TestClient) -> None:
    headers, _ = _register(client)
    payload = pack(
        entry("EPICERIE LUNE", logo=_embedded()),
        entry("VELO RAPIDE", TRANSIT, logo=_linked()),
        entry("SANS LOGO"),
    )

    status_code, body = preview(client, headers, pack=payload)

    assert status_code == 200
    assert body["logo_count"] == 2
    assert body["logo_download_count"] == 1


def test_an_embedded_logo_lands_normalized_on_the_new_rule(client: TestClient) -> None:
    headers, _ = _register(client)

    status_code, body = import_pack(
        client, headers, pack=pack(entry("EPICERIE LUNE", logo=_embedded(_picture("JPEG"))))
    )

    assert status_code == 200
    assert body["created_count"] == 1
    assert body["logo_count"] == 1
    assert body["logo_failures"] == []
    rule = _rules(client, headers)["EPICERIE LUNE"]
    assert rule["logo_updated_at"] is not None
    image = _logo(client, headers, rule["id"])
    assert image is not None
    with Image.open(io.BytesIO(image)) as stored:
        assert (stored.format, stored.size) == ("PNG", (256, 256))


@pytest.mark.parametrize(
    "logo",
    [
        {"data": "not base64!"},
        {"data": _embedded()["data"], "url": LOGO_URL},
        {"url": LOGO_URL, "source": "https://commons.wikimedia.org/"},
        {"url": LOGO_URL, "license": "CC0"},
        {},
    ],
    ids=["bad-base64", "both-forms", "no-license", "no-source", "empty"],
)
def test_a_malformed_logo_is_refused(client: TestClient, logo: dict[str, str]) -> None:
    headers, _ = _register(client)

    status_code, _ = preview(client, headers, pack=pack(entry("EPICERIE LUNE", logo=logo)))

    assert status_code == 422


# --- host allowlist ------------------------------------------------------------------------


@pytest.mark.parametrize(
    "url",
    [
        # Off the host.
        "http://upload.wikimedia.org/wikipedia/commons/a/ab/Logo.png",
        "https://example.com/wikipedia/commons/a/ab/Logo.png",
        "https://commons.wikimedia.org/wiki/File:Logo.png",
        "https://upload.wikimedia.org.example.com/wikipedia/commons/a/ab/Logo.png",
        "https://user@upload.wikimedia.org/wikipedia/commons/a/ab/Logo.png",
        "https://upload.wikimedia.org:8443/wikipedia/commons/a/ab/Logo.png",
        "https://UPLOAD.wikimedia.org/wikipedia/commons/a/ab/Logo.png",
        "https://upload.wikimedia.org\\@example.com/wikipedia/commons/a/ab/Logo.png",
        "https://upload.wikimedia.org/wikipedia/commons/a/ab/Logo .png",
        "ftp://upload.wikimedia.org/wikipedia/commons/a/ab/Logo.png",
        # On the host, but not a Commons file: fair-use files live under each Wikipedia.
        "https://upload.wikimedia.org/",
        "https://upload.wikimedia.org/logo.png",
        "https://upload.wikimedia.org/wikipedia/en/a/ab/Logo.png",
        "https://upload.wikimedia.org/wikipedia/fr/a/ab/Logo.png",
        "https://upload.wikimedia.org/wikipedia/commons/",
        "https://upload.wikimedia.org/wikipedia/commons/../en/a/ab/Logo.png",
        "https://upload.wikimedia.org/wikipedia/commons/%2e%2e/en/a/ab/Logo.png",
        "https://upload.wikimedia.org/wikipedia/commons/./a/ab/Logo.png",
        "https://upload.wikimedia.org/wikipedia/commonsfake/a/ab/Logo.png",
    ],
)
def test_a_link_off_wikimedia_commons_is_refused_at_validation(
    client: TestClient, web: _Web, url: str
) -> None:
    headers, _ = _register(client)

    for send in (preview, import_pack):
        status_code, body = send(
            client,
            headers,
            pack=pack(entry("EPICERIE LUNE", logo=_linked(url))),
            download_logos=True,
        )
        assert status_code == 422
        assert "upload.wikimedia.org" in str(body)
    assert web.requests == []


# --- size caps -----------------------------------------------------------------------------


def test_an_embedded_logo_over_the_per_logo_cap_is_refused(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    headers, _ = _register(client)
    monkeypatch.setattr(schema_module, "MAX_LOGO_BYTES", 100)

    status_code, _ = preview(
        client, headers, pack=pack(entry("EPICERIE LUNE", logo=_embedded(b"x" * 101)))
    )

    assert status_code == 422


def test_embedded_logos_over_the_per_pack_cap_are_refused(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    headers, _ = _register(client)
    monkeypatch.setattr(schema_module, "MAX_PACK_LOGO_BYTES", 150)
    payload = pack(
        entry("EPICERIE LUNE", logo=_embedded(b"x" * 90)),
        entry("VELO RAPIDE", logo=_embedded(b"y" * 90)),
    )

    status_code, _ = preview(client, headers, pack=payload)

    assert status_code == 422


def test_a_download_over_the_per_logo_cap_fails_without_blocking_its_rule(
    client: TestClient, web: _Web, monkeypatch: pytest.MonkeyPatch
) -> None:
    headers, _ = _register(client)
    monkeypatch.setattr(download_module, "MAX_LOGO_BYTES", 100)
    web.serve(LOGO_URL, b"x" * 101)

    _, body = import_pack(
        client, headers, pack=pack(entry("EPICERIE LUNE", logo=_linked())), download_logos=True
    )

    assert body["created_count"] == 1
    assert body["logo_failures"] == [
        {"index": 0, "pattern": "EPICERIE LUNE", "reason": "too_large"}
    ]
    assert _rules(client, headers)["EPICERIE LUNE"]["logo_updated_at"] is None


def test_downloads_share_the_per_pack_cap(
    client: TestClient, web: _Web, monkeypatch: pytest.MonkeyPatch
) -> None:
    headers, _ = _register(client)
    picture = _picture()
    monkeypatch.setattr(service_module, "MAX_PACK_LOGO_BYTES", len(picture) + 10)
    web.serve(LOGO_URL, picture)
    web.serve(OTHER_LOGO_URL, picture)
    payload = pack(
        entry("EPICERIE LUNE", logo=_linked()),
        entry("VELO RAPIDE", logo=_linked(OTHER_LOGO_URL)),
    )

    _, body = import_pack(client, headers, pack=payload, download_logos=True)

    assert body["created_count"] == 2
    assert body["logo_count"] == 1
    assert [failure["reason"] for failure in body["logo_failures"]] == ["too_large"]


# --- opt-in download -----------------------------------------------------------------------


def test_linked_logos_are_not_downloaded_by_default(client: TestClient, web: _Web) -> None:
    headers, _ = _register(client)
    web.serve(LOGO_URL)

    _, body = import_pack(client, headers, pack=pack(entry("EPICERIE LUNE", logo=_linked())))

    assert web.requests == []
    assert body["created_count"] == 1
    assert body["logo_count"] == 0
    assert body["logo_skipped_count"] == 1
    assert body["logo_failures"] == []
    assert _rules(client, headers)["EPICERIE LUNE"]["logo_updated_at"] is None


def test_preview_never_downloads(client: TestClient, web: _Web) -> None:
    headers, _ = _register(client)

    preview(client, headers, pack=pack(entry("EPICERIE LUNE", logo=_linked())))

    assert web.requests == []


def test_a_requested_download_fetches_every_link_once_with_a_generic_agent(
    client: TestClient, web: _Web
) -> None:
    headers, _ = _register(client)
    web.serve(LOGO_URL)
    web.serve(OTHER_LOGO_URL)
    payload = pack(
        entry("EPICERIE LUNE", logo=_linked()),
        entry("EPICERIE LUNE BIS", logo=_linked()),
        entry("VELO RAPIDE", TRANSIT, logo=_linked(OTHER_LOGO_URL)),
    )

    _, body = import_pack(client, headers, pack=payload, download_logos=True)

    assert body["logo_count"] == 3
    assert body["logo_failures"] == []
    assert sorted(str(request.url) for request in web.requests) == sorted(
        [LOGO_URL, OTHER_LOGO_URL]
    )
    for request in web.requests:
        assert request.method == "GET"
        assert request.headers["user-agent"].startswith("Bastide/")
        assert "cookie" not in request.headers
        assert "authorization" not in request.headers
    rules = _rules(client, headers)
    assert all(rules[name]["logo_updated_at"] for name in rules)


def test_re_importing_a_pack_downloads_no_logo_already_stored(
    client: TestClient, web: _Web
) -> None:
    headers, _ = _register(client)
    web.serve(LOGO_URL)
    web.serve(OTHER_LOGO_URL)
    payload = pack(
        entry("EPICERIE LUNE", logo=_linked()),
        entry("VELO RAPIDE", TRANSIT, logo=_linked(OTHER_LOGO_URL)),
    )
    import_pack(client, headers, pack=payload, download_logos=True)
    web.requests.clear()

    _, body = import_pack(client, headers, pack=payload, download_logos=True)

    # Both rules already carry their logo: the second import has nothing to fetch.
    assert body["logo_count"] == 0
    assert body["logo_failures"] == []
    assert web.requests == []


def test_a_downloaded_jpeg_thumbnail_is_stored_as_a_png(client: TestClient, web: _Web) -> None:
    headers, _ = _register(client)
    url = "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Logo.svg/320px-Logo.jpg"
    jpeg = _picture("JPEG")
    web.routes[url] = lambda _: httpx.Response(
        200, content=jpeg, headers={"content-type": "image/jpeg"}
    )

    _, body = import_pack(
        client, headers, pack=pack(entry("EPICERIE LUNE", logo=_linked(url))), download_logos=True
    )

    assert body["logo_count"] == 1
    image = _logo(client, headers, _rules(client, headers)["EPICERIE LUNE"]["id"])
    assert image is not None
    with Image.open(io.BytesIO(image)) as stored:
        assert (stored.format, stored.size) == ("PNG", (256, 256))


def test_a_redirect_on_the_allowed_host_is_followed(client: TestClient, web: _Web) -> None:
    headers, _ = _register(client)
    web.serve(LOGO_URL, b"", status=301, location=OTHER_LOGO_URL)
    web.serve(OTHER_LOGO_URL)

    _, body = import_pack(
        client, headers, pack=pack(entry("EPICERIE LUNE", logo=_linked())), download_logos=True
    )

    assert body["logo_count"] == 1


@pytest.mark.parametrize(
    "location",
    [
        "https://example.com/track.png",
        "https://upload.wikimedia.org/wikipedia/en/a/ab/Fair_use_logo.png",
        "/wikipedia/en/a/ab/Fair_use_logo.png",
    ],
    ids=["other-host", "fair-use", "relative-fair-use"],
)
def test_a_redirect_off_wikimedia_commons_is_never_followed(
    client: TestClient, web: _Web, location: str
) -> None:
    headers, _ = _register(client)
    web.serve(LOGO_URL, b"", status=302, location=location)
    web.serve(str(httpx.URL(LOGO_URL).join(location)))

    _, body = import_pack(
        client, headers, pack=pack(entry("EPICERIE LUNE", logo=_linked())), download_logos=True
    )

    assert [str(request.url) for request in web.requests] == [LOGO_URL]
    assert body["created_count"] == 1
    assert body["logo_failures"] == [
        {"index": 0, "pattern": "EPICERIE LUNE", "reason": "download_failed"}
    ]


@pytest.mark.parametrize("status", [404, 500])
def test_an_error_status_is_a_failed_download(client: TestClient, web: _Web, status: int) -> None:
    headers, _ = _register(client)
    web.serve(LOGO_URL, b"gone", status=status)

    _, body = import_pack(
        client, headers, pack=pack(entry("EPICERIE LUNE", logo=_linked())), download_logos=True
    )

    assert body["created_count"] == 1
    assert [failure["reason"] for failure in body["logo_failures"]] == ["download_failed"]


# --- failing logos never block the import --------------------------------------------------


def test_failing_logos_are_reported_and_the_rules_still_import(
    client: TestClient, web: _Web
) -> None:
    headers, _ = _register(client)
    web.serve(OTHER_LOGO_URL, b"<html>not a picture</html>")
    payload = pack(
        entry("EPICERIE LUNE", logo=_embedded(b"not a picture at all")),
        entry("VELO RAPIDE", TRANSIT, logo=_linked(OTHER_LOGO_URL)),
        entry("SANS RESEAU", logo=_linked()),  # unreachable: no route served
        entry("CAFE DU PORT", logo=_embedded()),
    )

    status_code, body = import_pack(client, headers, pack=payload, download_logos=True)

    assert status_code == 200
    assert body["created_count"] == 4
    assert body["logo_count"] == 1
    assert body["logo_failures"] == [
        {"index": 0, "pattern": "EPICERIE LUNE", "reason": "invalid_image"},
        {"index": 1, "pattern": "VELO RAPIDE", "reason": "invalid_image"},
        {"index": 2, "pattern": "SANS RESEAU", "reason": "download_failed"},
    ]
    rules = _rules(client, headers)
    assert rules["CAFE DU PORT"]["logo_updated_at"] is not None
    assert rules["EPICERIE LUNE"]["logo_updated_at"] is None


# --- duplicates ----------------------------------------------------------------------------


def _own_rule(client: TestClient, headers: dict[str, str], pattern: str) -> str:
    return _create_rule(
        client, headers, category_id_for_key(client, headers, GROCERIES), pattern=pattern
    )["id"]


def test_a_duplicate_gives_its_logo_to_the_users_rule_that_has_none(
    client: TestClient,
) -> None:
    headers, _ = _register(client)
    rule_id = _own_rule(client, headers, "EPICERIE LUNE")
    payload = pack(entry("epicerie lune", GROCERIES, logo=_embedded()))

    _, previewed = preview(client, headers, pack=payload)
    _, body = import_pack(client, headers, pack=payload)

    assert previewed["logo_count"] == 1
    assert body["created_count"] == 0
    assert body["skipped_count"] == 1
    assert body["logo_count"] == 1
    assert _logo(client, headers, rule_id) is not None


def test_a_duplicate_never_replaces_an_existing_logo(client: TestClient) -> None:
    headers, _ = _register(client)
    rule_id = _own_rule(client, headers, "EPICERIE LUNE")
    client.put(
        f"/api/v1/rules/{rule_id}/logo",
        headers=headers,
        files={"file": ("logo.png", _picture(colour=(0, 0, 255)), "image/png")},
    )
    before = _logo(client, headers, rule_id)
    payload = pack(entry("EPICERIE LUNE", GROCERIES, logo=_embedded()))

    _, previewed = preview(client, headers, pack=payload)
    _, body = import_pack(client, headers, pack=payload)

    assert previewed["logo_count"] == 0
    assert body["logo_count"] == 0
    assert body["logo_failures"] == []
    assert _logo(client, headers, rule_id) == before


def test_a_rule_repeated_in_the_pack_takes_the_first_logo(client: TestClient) -> None:
    headers, _ = _register(client)
    red, green = _picture(colour=(255, 0, 0)), _picture(colour=(0, 255, 0))
    payload = pack(
        entry("EPICERIE LUNE", logo=_embedded(red)),
        entry("EPICERIE LUNE", logo=_embedded(green)),
    )

    _, body = import_pack(client, headers, pack=payload)

    assert body["created_count"] == 1
    assert body["logo_count"] == 1
    image = _logo(client, headers, _rules(client, headers)["EPICERIE LUNE"]["id"])
    assert image is not None
    with Image.open(io.BytesIO(image)) as stored:
        assert stored.convert("RGB").getpixel((128, 128)) == (255, 0, 0)
