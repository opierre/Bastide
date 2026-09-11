"""Tests for category listing, user CRUD, and system-category read-only-ness."""

from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.features.categories.models import Category

USER_CATEGORY_PAYLOAD = {
    "name": "Vacances",
    "kind": "expense",
    "icon": "flight",
    "color": "#8B5CF6",
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
    token = response.json()["token"]
    return {"Authorization": f"Bearer {token}"}


def _insert_system_category(tmp_path: Path, name: str = "category.housing") -> str:
    """Insert a system category directly (there's no create-system-category endpoint)."""
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}", connect_args={"check_same_thread": False}
    )
    session = sessionmaker(bind=engine)()
    category = Category(
        user_id=None,
        parent_id=None,
        name=name,
        kind="expense",
        icon="home",
        color="#F59E0B",
        is_system=True,
    )
    session.add(category)
    session.commit()
    category_id = category.id
    session.close()
    return category_id


def test_create_category(client: TestClient) -> None:
    headers = _register(client)

    response = client.post("/api/v1/categories", json=USER_CATEGORY_PAYLOAD, headers=headers)

    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Vacances"
    assert body["kind"] == "expense"
    assert body["is_system"] is False
    assert body["user_id"] is not None


def test_list_categories_includes_system_and_user_rows(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    _insert_system_category(tmp_path)
    client.post("/api/v1/categories", json=USER_CATEGORY_PAYLOAD, headers=headers)

    response = client.get("/api/v1/categories", headers=headers)

    assert response.status_code == 200
    names = {c["name"] for c in response.json()}
    assert "category.housing" in names
    assert "Vacances" in names


def test_system_category_name_is_an_i18n_key(client: TestClient) -> None:
    """The seeded catalog stores keys, not display names — the frontend localizes them.

    Reads the row startup seeded rather than inserting one, and selects it **by name**: the
    catalog holds dozens of system rows, so "the first system category in the list" would
    assert against whichever one the query happened to order first.
    """
    headers = _register(client)

    response = client.get("/api/v1/categories", headers=headers)

    system_category = next(c for c in response.json() if c["name"] == "category.food")
    assert system_category["is_system"] is True
    assert system_category["user_id"] is None


def test_update_user_category(client: TestClient) -> None:
    headers = _register(client)
    create_response = client.post("/api/v1/categories", json=USER_CATEGORY_PAYLOAD, headers=headers)
    category_id = create_response.json()["id"]

    response = client.patch(
        f"/api/v1/categories/{category_id}", json={"name": "Voyages"}, headers=headers
    )

    assert response.status_code == 200
    assert response.json()["name"] == "Voyages"


def test_delete_user_category(client: TestClient) -> None:
    headers = _register(client)
    create_response = client.post("/api/v1/categories", json=USER_CATEGORY_PAYLOAD, headers=headers)
    category_id = create_response.json()["id"]

    response = client.delete(f"/api/v1/categories/{category_id}", headers=headers)
    assert response.status_code == 204

    # The list is never empty — the seeded system catalog is always there — so assert the
    # user's own rows are gone rather than that nothing at all remains.
    remaining = client.get("/api/v1/categories", headers=headers).json()
    assert [c for c in remaining if not c["is_system"]] == []
    assert category_id not in {c["id"] for c in remaining}


def test_cannot_update_system_category(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    category_id = _insert_system_category(tmp_path)

    response = client.patch(
        f"/api/v1/categories/{category_id}", json={"name": "Hacked"}, headers=headers
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "CATEGORY_NOT_FOUND"


def test_cannot_delete_system_category(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    category_id = _insert_system_category(tmp_path)

    response = client.delete(f"/api/v1/categories/{category_id}", headers=headers)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "CATEGORY_NOT_FOUND"


def test_cross_user_update_returns_404(client: TestClient) -> None:
    headers_a = _register(client, "amelie@example.com")
    create_response = client.post(
        "/api/v1/categories", json=USER_CATEGORY_PAYLOAD, headers=headers_a
    )
    category_id = create_response.json()["id"]

    headers_b = _register(client, "bruno@example.com")
    response = client.patch(
        f"/api/v1/categories/{category_id}", json={"name": "Hacked"}, headers=headers_b
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "CATEGORY_NOT_FOUND"


def test_categories_require_auth(client: TestClient) -> None:
    response = client.get("/api/v1/categories")

    assert response.status_code == 401
