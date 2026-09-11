"""Tests for the lazily created user settings row and its read/patch endpoints."""

from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import sessionmaker

from app.features.settings.models import UserSettings

DEFAULTS = {
    "ai_enabled": False,
    "inference_base_url": "http://127.0.0.1:11434/v1",
    "model_tag": None,
    "confidence_threshold": 0.80,
    "last_backup_at": None,
}


def _register(client: TestClient, email: str = "amelie@example.com") -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "correct-horse-battery-staple",
            "display_name": "Amelie",
            "locale": "fr",
            "currency": "eur",
        },
    )
    return {"Authorization": f"Bearer {response.json()['token']}"}


def _settings_row_count(tmp_path: Path) -> int:
    """Count `user_settings` rows straight from the `client` fixture's temp database."""
    engine = create_engine(f"sqlite:///{tmp_path / 'test.db'}")
    with sessionmaker(bind=engine)() as db:
        return db.scalar(select(func.count()).select_from(UserSettings)) or 0


def test_get_returns_defaults_for_a_fresh_user(client: TestClient) -> None:
    headers = _register(client)

    response = client.get("/api/v1/settings", headers=headers)

    assert response.status_code == 200
    assert response.json() == DEFAULTS


def test_get_is_idempotent_and_creates_one_row(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)

    first = client.get("/api/v1/settings", headers=headers)
    client.patch("/api/v1/settings", json={"model_tag": "gemma4:e4b"}, headers=headers)
    second = client.get("/api/v1/settings", headers=headers)

    assert first.json() == DEFAULTS
    # The second read returned the patched row, not a freshly defaulted one.
    assert second.json()["model_tag"] == "gemma4:e4b"
    assert _settings_row_count(tmp_path) == 1


def test_patch_updates_only_supplied_fields(client: TestClient) -> None:
    headers = _register(client)
    client.patch(
        "/api/v1/settings",
        json={"ai_enabled": True, "model_tag": "gemma4:e4b", "confidence_threshold": 0.6},
        headers=headers,
    )

    response = client.patch("/api/v1/settings", json={"confidence_threshold": 0.9}, headers=headers)

    assert response.status_code == 200
    assert response.json() == {
        "ai_enabled": True,
        "inference_base_url": "http://127.0.0.1:11434/v1",
        "model_tag": "gemma4:e4b",
        "confidence_threshold": 0.9,
        "last_backup_at": None,
    }


@pytest.mark.parametrize("threshold", [0.0, 0.5, 1.0])
def test_patch_accepts_thresholds_within_bounds(client: TestClient, threshold: float) -> None:
    headers = _register(client)

    response = client.patch(
        "/api/v1/settings", json={"confidence_threshold": threshold}, headers=headers
    )

    assert response.status_code == 200
    assert response.json()["confidence_threshold"] == threshold


@pytest.mark.parametrize("threshold", [-0.1, 1.1, 2])
def test_patch_rejects_thresholds_outside_bounds(client: TestClient, threshold: float) -> None:
    headers = _register(client)

    response = client.patch(
        "/api/v1/settings", json={"confidence_threshold": threshold}, headers=headers
    )

    assert response.status_code == 422


@pytest.mark.parametrize(
    "base_url",
    [
        "http://127.0.0.1:11434/v1",
        "http://localhost:8080/v1",
        "http://127.0.0.2:8080/v1",
        "https://127.0.0.1:8443/v1",
        "http://[::1]:11434/v1",
    ],
)
def test_patch_accepts_loopback_base_urls(client: TestClient, base_url: str) -> None:
    headers = _register(client)

    response = client.patch(
        "/api/v1/settings", json={"inference_base_url": base_url}, headers=headers
    )

    assert response.status_code == 200
    assert response.json()["inference_base_url"] == base_url


@pytest.mark.parametrize(
    "base_url",
    [
        "http://example.com/v1",
        "https://api.openai.com/v1",
        "http://192.168.1.20:11434/v1",
        "ftp://127.0.0.1/v1",
        "127.0.0.1:11434",
        "",
    ],
)
def test_patch_rejects_non_loopback_or_non_http_base_urls(
    client: TestClient, base_url: str
) -> None:
    headers = _register(client)

    response = client.patch(
        "/api/v1/settings", json={"inference_base_url": base_url}, headers=headers
    )

    assert response.status_code == 422


def test_settings_are_user_scoped(client: TestClient) -> None:
    alice = _register(client, "alice@example.com")
    bob = _register(client, "bob@example.com")

    client.patch(
        "/api/v1/settings",
        json={"ai_enabled": True, "model_tag": "gemma4:e4b"},
        headers=alice,
    )

    assert client.get("/api/v1/settings", headers=bob).json() == DEFAULTS
    assert client.get("/api/v1/settings", headers=alice).json()["ai_enabled"] is True


def test_settings_require_authentication(client: TestClient) -> None:
    assert client.get("/api/v1/settings").status_code == 401
