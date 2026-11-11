"""Tests for the background rule pack import: the run, its progress events, its snapshot.

The logo fetcher is a fake: nothing leaves the process, and each URL settles with the bytes or
the failure the test gave it.
"""

import io
from collections.abc import Generator, Iterable
from datetime import UTC, datetime
from typing import Any, cast

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from PIL import Image

from app.core.progress import ProgressBus, get_progress_bus
from app.features.rules.packs.download import (
    LogoDownloadError,
    LogoFetcher,
    OnLogoResult,
    get_logo_fetcher,
)
from app.features.rules.packs.runs import (
    IMPORT_FAILED_MESSAGE,
    PackImportRunStore,
    get_pack_import_launcher,
    get_pack_import_run_store,
)
from tests.api import register_user
from tests.features.categorization.conftest import RunLauncherSpy
from tests.features.rules.packs.helpers import entry, pack

RUNS = "/api/v1/rules/packs/import-runs"
WS = "/api/v1/runs/ws"
COMMONS = "https://upload.wikimedia.org/wikipedia/commons"
LUNE = f"{COMMONS}/a/ab/Epicerie_Lune_logo.png"
VELO = f"{COMMONS}/c/cd/Velo_Rapide_logo.png"
PHARE = f"{COMMONS}/e/ef/Cafe_du_Phare_logo.png"


def _picture() -> bytes:
    output = io.BytesIO()
    Image.new("RGB", (300, 200), (40, 120, 200)).save(output, format="PNG")
    return output.getvalue()


def _linked(url: str) -> dict[str, str]:
    return {"url": url, "license": "CC0", "source": "https://commons.wikimedia.org/wiki/File:X"}


class FakeFetcher:
    """A `LogoFetcher` answering from a table: bytes, or a failure, per URL."""

    def __init__(self) -> None:
        self.answers: dict[str, bytes | LogoDownloadError] = {}
        self.calls: list[list[str]] = []
        self.explode = False

    async def fetch_all(
        self, urls: Iterable[str], max_total_bytes: int, on_result: OnLogoResult | None = None
    ) -> dict[str, bytes | LogoDownloadError]:
        if self.explode:
            raise RuntimeError("boom")
        distinct = list(dict.fromkeys(urls))
        self.calls.append(distinct)
        results: dict[str, bytes | LogoDownloadError] = {}
        for url in distinct:
            results[url] = self.answers.get(url, LogoDownloadError("unreachable"))
            if on_result is not None:
                on_result(url, results[url])
        return results


@pytest.fixture
def overrides(client: TestClient) -> Generator[tuple[FakeFetcher, RunLauncherSpy, ProgressBus]]:
    """Fresh fetcher, launcher, bus and run store per test: nothing leaks between tests."""
    app = cast(FastAPI, client.app)
    fetcher, launcher, bus = FakeFetcher(), RunLauncherSpy(), ProgressBus()
    store = PackImportRunStore()
    app.dependency_overrides[get_logo_fetcher] = lambda: cast(LogoFetcher, fetcher)
    app.dependency_overrides[get_pack_import_launcher] = lambda: launcher
    app.dependency_overrides[get_progress_bus] = lambda: bus
    app.dependency_overrides[get_pack_import_run_store] = lambda: store
    yield fetcher, launcher, bus
    launcher.discard()


def _logo_pack() -> dict[str, Any]:
    return pack(
        entry("EPICERIE LUNE", logo=_linked(LUNE)),
        entry("VELO RAPIDE", logo=_linked(VELO)),
        entry("CAFE DU PHARE", logo=_linked(PHARE)),
        entry("SANS LOGO"),
    )


def test_an_import_with_linked_logos_streams_one_event_per_logo_then_its_result(
    client: TestClient, overrides: tuple[FakeFetcher, RunLauncherSpy, ProgressBus]
) -> None:
    fetcher, launcher, _ = overrides
    fetcher.answers = {LUNE: _picture(), PHARE: _picture()}  # VELO is unreachable.
    user = register_user(client)

    with client.websocket_connect(WS, headers=user.headers) as socket:
        assert socket.receive_json()["runs"] == []
        response = client.post(
            RUNS, json={"pack": _logo_pack(), "download_logos": True}, headers=user.headers
        )
        assert response.status_code == 202, response.text
        run = response.json()
        assert run["status"] == "running"
        assert run["result"] is None
        launcher.drain()

        events = [socket.receive_json()["event"] for _ in range(5)]

    assert {event["run_id"] for event in events} == {run["id"]}
    assert {event["kind"] for event in events} == {"rule_pack_import"}
    assert [event["event"] for event in events] == [
        "started",
        "progress",
        "progress",
        "progress",
        "finished",
    ]
    assert [(event["done"], event["total"]) for event in events] == [
        (0, 3),
        (1, 3),
        (2, 3),
        (3, 3),
        (3, 3),
    ]
    assert events[0]["counts"]["created"] == 4
    assert events[3]["counts"]["downloaded"] == 2
    assert events[3]["counts"]["download_failed"] == 1
    assert events[4]["counts"] == {
        "created": 4,
        "skipped": 0,
        "unresolved": 0,
        "recategorized": 0,
        "logos": 2,
        "logos_skipped": 0,
        "logos_failed": 1,
    }

    snapshot = client.get(f"{RUNS}/{run['id']}", headers=user.headers).json()
    assert snapshot["status"] == "finished"
    assert (snapshot["logo_done"], snapshot["logo_total"]) == (3, 3)
    assert snapshot["finished_at"] is not None
    assert snapshot["result"] == {
        "created_count": 4,
        "skipped_count": 0,
        "unresolved": [],
        "recategorized_count": 0,
        "logo_count": 2,
        "logo_skipped_count": 0,
        "logo_failures": [{"index": 1, "pattern": "VELO RAPIDE", "reason": "download_failed"}],
    }
    rules = {r["pattern"]: r for r in client.get("/api/v1/rules", headers=user.headers).json()}
    assert rules["EPICERIE LUNE"]["logo_updated_at"] is not None
    assert rules["VELO RAPIDE"]["logo_updated_at"] is None


def test_the_run_is_returned_before_anything_is_imported(
    client: TestClient, overrides: tuple[FakeFetcher, RunLauncherSpy, ProgressBus]
) -> None:
    fetcher, launcher, _ = overrides
    user = register_user(client)

    run = client.post(RUNS, json={"pack": _logo_pack()}, headers=user.headers).json()

    assert client.get("/api/v1/rules", headers=user.headers).json() == []
    assert client.get(f"{RUNS}/{run['id']}", headers=user.headers).json()["status"] == "running"
    launcher.drain()
    snapshot = client.get(f"{RUNS}/{run['id']}", headers=user.headers).json()
    assert snapshot["status"] == "finished"
    assert snapshot["logo_total"] == 0
    assert snapshot["result"]["logo_skipped_count"] == 3
    assert fetcher.calls == []
    assert len(client.get("/api/v1/rules", headers=user.headers).json()) == 4


def test_a_second_import_is_refused_while_one_is_running(
    client: TestClient, overrides: tuple[FakeFetcher, RunLauncherSpy, ProgressBus]
) -> None:
    _, launcher, _ = overrides
    user = register_user(client)
    client.post(RUNS, json={"pack": _logo_pack()}, headers=user.headers)

    response = client.post(RUNS, json={"pack": _logo_pack()}, headers=user.headers)

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "RULE_PACK_IMPORT_IN_PROGRESS"
    launcher.drain()
    assert client.post(RUNS, json={"pack": _logo_pack()}, headers=user.headers).status_code == 202


def test_an_unknown_builtin_pack_is_refused_before_any_run_starts(
    client: TestClient, overrides: tuple[FakeFetcher, RunLauncherSpy, ProgressBus]
) -> None:
    _, launcher, _ = overrides
    user = register_user(client)

    response = client.post(RUNS, json={"builtin_id": "nope"}, headers=user.headers)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "RULE_PACK_NOT_FOUND"
    assert launcher.pending == []


def test_a_background_import_of_the_bundled_pack_marks_it_imported(
    client: TestClient, overrides: tuple[FakeFetcher, RunLauncherSpy, ProgressBus]
) -> None:
    _, launcher, _ = overrides
    user = register_user(client)

    response = client.post(RUNS, json={"builtin_id": "fr-common.v1"}, headers=user.headers)
    assert response.status_code == 202, response.text
    launcher.drain()

    listed = client.get("/api/v1/rules/packs/builtin", headers=user.headers).json()
    assert [entry_["imported"] for entry_ in listed] == [True]


def test_a_run_is_only_visible_to_its_user(
    client: TestClient, overrides: tuple[FakeFetcher, RunLauncherSpy, ProgressBus]
) -> None:
    owner = register_user(client)
    other = register_user(client, "basile@example.com")
    run = client.post(RUNS, json={"pack": _logo_pack()}, headers=owner.headers).json()

    response = client.get(f"{RUNS}/{run['id']}", headers=other.headers)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "RULE_PACK_IMPORT_RUN_NOT_FOUND"
    assert client.get(f"{RUNS}/{run['id']}", headers=owner.headers).status_code == 200


def test_starting_or_reading_a_run_requires_authentication(
    client: TestClient, overrides: tuple[FakeFetcher, RunLauncherSpy, ProgressBus]
) -> None:
    assert client.post(RUNS, json={"pack": _logo_pack()}).status_code == 401
    assert client.get(f"{RUNS}/whatever").status_code == 401


def test_a_run_that_cannot_finish_reports_failed_and_keeps_its_rules(
    client: TestClient, overrides: tuple[FakeFetcher, RunLauncherSpy, ProgressBus]
) -> None:
    fetcher, launcher, _ = overrides
    fetcher.explode = True
    user = register_user(client)

    with client.websocket_connect(WS, headers=user.headers) as socket:
        socket.receive_json()
        run = client.post(
            RUNS, json={"pack": _logo_pack(), "download_logos": True}, headers=user.headers
        ).json()
        launcher.drain()
        events = [socket.receive_json()["event"] for _ in range(2)]

    assert [event["event"] for event in events] == ["started", "failed"]
    assert events[1]["error_message"] == IMPORT_FAILED_MESSAGE
    snapshot = client.get(f"{RUNS}/{run['id']}", headers=user.headers).json()
    assert snapshot["status"] == "failed"
    assert snapshot["error_message"] == IMPORT_FAILED_MESSAGE
    assert snapshot["result"] is None
    # The rules were committed before the downloads began.
    assert len(client.get("/api/v1/rules", headers=user.headers).json()) == 4


def test_the_store_forgets_the_oldest_settled_runs() -> None:
    store = PackImportRunStore(max_runs_per_user=2)
    now = datetime(2026, 3, 4, 10, 0, tzinfo=UTC)
    first = store.start("user", now)
    first.status = "finished"
    second = store.start("user", now)
    second.status = "finished"

    third = store.start("user", now)

    assert store.get("user", first.id) is None
    assert store.get("user", second.id) is second
    assert store.get("user", third.id) is third
    assert store.get("someone-else", third.id) is None
