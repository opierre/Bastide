"""Tests for categorization rule CRUD."""

from fastapi.testclient import TestClient

CATEGORY_PAYLOAD = {
    "name": "Courses",
    "kind": "expense",
    "icon": "shopping_cart",
    "color": "#10B981",
}

RULE_PAYLOAD = {
    "priority": 1,
    "match_field": "description_clean",
    "match_type": "contains",
    "pattern": "CARREFOUR",
    "enabled": True,
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


def _create_category(client: TestClient, headers: dict[str, str]) -> str:
    response = client.post("/api/v1/categories", json=CATEGORY_PAYLOAD, headers=headers)
    return response.json()["id"]


def _create_rule(
    client: TestClient, headers: dict[str, str], category_id: str, **overrides: object
) -> dict:
    payload = {**RULE_PAYLOAD, "category_id": category_id, **overrides}
    response = client.post("/api/v1/rules", json=payload, headers=headers)
    return response.json()


def test_create_rule(client: TestClient) -> None:
    headers = _register(client)
    category_id = _create_category(client, headers)

    rule = _create_rule(client, headers, category_id)

    assert rule["priority"] == 1
    assert rule["match_field"] == "description_clean"
    assert rule["match_type"] == "contains"
    assert rule["pattern"] == "CARREFOUR"
    assert rule["category_id"] == category_id
    assert rule["enabled"] is True


def test_list_rules_in_priority_order(client: TestClient) -> None:
    headers = _register(client)
    category_id = _create_category(client, headers)
    _create_rule(client, headers, category_id, priority=2, pattern="B")
    _create_rule(client, headers, category_id, priority=1, pattern="A")

    response = client.get("/api/v1/rules", headers=headers)

    body = response.json()
    assert [r["priority"] for r in body] == [1, 2]


def test_update_rule(client: TestClient) -> None:
    headers = _register(client)
    category_id = _create_category(client, headers)
    rule = _create_rule(client, headers, category_id)

    response = client.patch(
        f"/api/v1/rules/{rule['id']}",
        json={"priority": 5, "enabled": False},
        headers=headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert body["priority"] == 5
    assert body["enabled"] is False
    assert body["pattern"] == "CARREFOUR"


def test_delete_rule(client: TestClient) -> None:
    headers = _register(client)
    category_id = _create_category(client, headers)
    rule = _create_rule(client, headers, category_id)

    response = client.delete(f"/api/v1/rules/{rule['id']}", headers=headers)
    assert response.status_code == 204

    list_response = client.get("/api/v1/rules", headers=headers)
    assert list_response.json() == []


def test_cross_user_rule_access_returns_404(client: TestClient) -> None:
    headers_a = _register(client, "amelie@example.com")
    category_id = _create_category(client, headers_a)
    rule = _create_rule(client, headers_a, category_id)

    headers_b = _register(client, "bruno@example.com")
    response = client.patch(f"/api/v1/rules/{rule['id']}", json={"priority": 9}, headers=headers_b)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "RULE_NOT_FOUND"


def test_rules_require_auth(client: TestClient) -> None:
    response = client.get("/api/v1/rules")

    assert response.status_code == 401
