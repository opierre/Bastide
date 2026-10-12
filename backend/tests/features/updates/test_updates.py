"""Tests for `GET /api/v1/settings/updates`, with GitHub and the clock mocked throughout."""

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Annotated

import pytest
from fastapi import Depends
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.features.settings.repository import SettingsRepository
from app.features.settings.service import SettingsService
from app.features.updates.releases import ReleaseCheckFailed
from app.features.updates.router import get_update_service
from app.features.updates.service import UpdateService
from tests.api import register as _register

URL = "/api/v1/settings/updates"
CURRENT = "0.1.0"
START = datetime(2026, 10, 11, 9, 0, tzinfo=UTC)


@dataclass
class FakeReleases:
    """A release source answering `latest`, or failing as if offline."""

    latest: str | None = "0.2.0"
    offline: bool = False
    calls: int = 0

    async def latest_version(self) -> str | None:
        self.calls += 1
        if self.offline:
            raise ReleaseCheckFailed("offline")
        return self.latest


@dataclass
class Clock:
    now: datetime = START

    def __call__(self) -> datetime:
        return self.now


@pytest.fixture
def releases() -> FakeReleases:
    return FakeReleases()


@pytest.fixture
def clock() -> Clock:
    return Clock()


@pytest.fixture
def headers(client: TestClient, releases: FakeReleases, clock: Clock) -> dict[str, str]:
    """A registered user, with the update service wired to the fakes."""

    def service(db: Annotated[Session, Depends(get_db)]) -> UpdateService:
        return UpdateService(SettingsService(SettingsRepository(db)), releases, CURRENT, clock)

    client.app.dependency_overrides[get_update_service] = service
    return _register(client)


def _opt_in(client: TestClient, headers: dict[str, str]) -> None:
    response = client.patch(
        "/api/v1/settings", json={"update_check_enabled": True}, headers=headers
    )
    assert response.status_code == 200
    assert response.json()["update_check_enabled"] is True


def test_off_by_default_and_github_is_never_asked(
    client: TestClient, headers: dict[str, str], releases: FakeReleases
) -> None:
    response = client.get(URL, headers=headers)

    assert response.status_code == 200
    assert response.json() == {
        "enabled": False,
        "current_version": CURRENT,
        "latest_version": None,
        "update_available": False,
        "release_url": None,
        "checked_at": None,
        "reachable": True,
    }
    assert releases.calls == 0


def test_a_newer_release_is_offered_with_its_page(
    client: TestClient, headers: dict[str, str]
) -> None:
    _opt_in(client, headers)

    body = client.get(URL, headers=headers).json()

    assert body["enabled"] is True
    assert body["latest_version"] == "0.2.0"
    assert body["update_available"] is True
    assert body["release_url"] == "https://github.com/opierre/Bastide/releases/tag/v0.2.0"
    assert datetime.fromisoformat(body["checked_at"]) == START
    assert body["reachable"] is True


def test_the_same_version_is_not_an_update(
    client: TestClient, headers: dict[str, str], releases: FakeReleases
) -> None:
    releases.latest = CURRENT
    _opt_in(client, headers)

    body = client.get(URL, headers=headers).json()

    assert body["latest_version"] == CURRENT
    assert body["update_available"] is False
    assert body["release_url"] is None


def test_no_published_release_is_not_an_update(
    client: TestClient, headers: dict[str, str], releases: FakeReleases
) -> None:
    releases.latest = None
    _opt_in(client, headers)

    body = client.get(URL, headers=headers).json()

    assert body["update_available"] is False
    assert body["reachable"] is True


def test_offline_is_reported_not_raised(
    client: TestClient, headers: dict[str, str], releases: FakeReleases
) -> None:
    releases.offline = True
    _opt_in(client, headers)

    response = client.get(URL, headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert body["reachable"] is False
    assert body["update_available"] is False
    assert body["checked_at"] is None


def test_github_is_asked_at_most_once_a_day(
    client: TestClient, headers: dict[str, str], releases: FakeReleases, clock: Clock
) -> None:
    _opt_in(client, headers)

    client.get(URL, headers=headers)
    clock.now = START + timedelta(hours=23)
    releases.latest = "0.3.0"
    cached = client.get(URL, headers=headers).json()

    assert releases.calls == 1
    assert cached["latest_version"] == "0.2.0"

    clock.now = START + timedelta(days=1)
    fresh = client.get(URL, headers=headers).json()

    assert releases.calls == 2
    assert fresh["latest_version"] == "0.3.0"
    assert datetime.fromisoformat(fresh["checked_at"]) == clock.now


def test_offline_keeps_what_the_last_check_found(
    client: TestClient, headers: dict[str, str], releases: FakeReleases, clock: Clock
) -> None:
    _opt_in(client, headers)
    client.get(URL, headers=headers)

    clock.now = START + timedelta(days=2)
    releases.offline = True
    body = client.get(URL, headers=headers).json()

    assert body["reachable"] is False
    assert body["latest_version"] == "0.2.0"
    assert body["update_available"] is True
    assert datetime.fromisoformat(body["checked_at"]) == START


def test_a_clock_set_back_makes_the_check_due(
    client: TestClient, headers: dict[str, str], releases: FakeReleases, clock: Clock
) -> None:
    _opt_in(client, headers)
    client.get(URL, headers=headers)

    clock.now = START - timedelta(days=30)
    client.get(URL, headers=headers)

    assert releases.calls == 2


def test_turning_it_off_stops_the_checks(
    client: TestClient, headers: dict[str, str], releases: FakeReleases, clock: Clock
) -> None:
    _opt_in(client, headers)
    client.get(URL, headers=headers)
    client.patch("/api/v1/settings", json={"update_check_enabled": False}, headers=headers)

    clock.now = START + timedelta(days=3)
    body = client.get(URL, headers=headers).json()

    assert body["enabled"] is False
    assert releases.calls == 1


def test_the_update_check_requires_authentication(client: TestClient) -> None:
    assert client.get(URL).status_code == 401
