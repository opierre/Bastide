"""Tests for the goals surface: CRUD, validation, archiving, and user scoping.

What is at stake here is that a goal stays a *virtual envelope*: it carries no account, its
progress is derived rather than stored, and deleting one archives it instead of taking its
history with it.
"""

from datetime import date

from fastapi.testclient import TestClient

GOAL_PAYLOAD = {
    "name": "Fonds d'urgence",
    "target_minor": 1_000_000,
    "icon": "shield",
    "color": "iris",
}


def register(client: TestClient, email: str = "amelie@example.com") -> dict[str, str]:
    """Register a user and return the auth header their requests carry."""
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
    assert response.status_code == 201, response.json()
    return {"Authorization": f"Bearer {response.json()['token']}"}


def create_goal(client: TestClient, headers: dict[str, str], **overrides: object) -> dict:
    """Create a goal and return it."""
    response = client.post("/api/v1/goals", json={**GOAL_PAYLOAD, **overrides}, headers=headers)
    assert response.status_code == 201, response.json()
    return dict(response.json())


def list_goals(client: TestClient, headers: dict[str, str], **params: str) -> list[dict]:
    response = client.get("/api/v1/goals", params=params, headers=headers)
    assert response.status_code == 200, response.json()
    return list(response.json())


# --- creation -------------------------------------------------------------------------------


def test_a_new_goal_starts_active_and_empty(client: TestClient) -> None:
    headers = register(client)

    goal = create_goal(client, headers, target_date="2028-06-01")

    assert goal["name"] == "Fonds d'urgence"
    assert goal["target_minor"] == 1_000_000
    assert goal["target_date"] == "2028-06-01"
    assert goal["status"] == "active"
    assert goal["progress_minor"] == 0
    assert goal["progress_pct"] == 0.0


def test_currency_is_copied_from_the_user(client: TestClient) -> None:
    headers = register(client)

    assert create_goal(client, headers)["currency"] == "EUR"


def test_a_goal_carries_no_account(client: TestClient) -> None:
    """The drawn design shows no account on a goal anywhere, so the field is refused rather
    than accepted and dropped — a silently ignored id would read as stored."""
    headers = register(client)

    response = client.post(
        "/api/v1/goals",
        json={**GOAL_PAYLOAD, "account_id": "some-account"},
        headers=headers,
    )

    assert response.status_code == 422
    assert "account_id" not in create_goal(client, headers)


def test_a_target_must_be_positive(client: TestClient) -> None:
    headers = register(client)

    for target in (0, -1):
        response = client.post(
            "/api/v1/goals", json={**GOAL_PAYLOAD, "target_minor": target}, headers=headers
        )
        assert response.status_code == 422, target


# --- listing and patching -------------------------------------------------------------------


def test_listing_returns_the_users_goals_oldest_first(client: TestClient) -> None:
    headers = register(client)
    create_goal(client, headers, name="Fonds d'urgence")
    create_goal(client, headers, name="Voyage Japon")

    assert [goal["name"] for goal in list_goals(client, headers)] == [
        "Fonds d'urgence",
        "Voyage Japon",
    ]


def test_patching_edits_the_goal(client: TestClient) -> None:
    headers = register(client)
    goal = create_goal(client, headers)

    response = client.patch(
        f"/api/v1/goals/{goal['id']}",
        json={"name": "Nouvelle cuisine", "target_minor": 800_000, "icon": "kitchen"},
        headers=headers,
    )

    assert response.status_code == 200, response.json()
    patched = response.json()
    assert patched["name"] == "Nouvelle cuisine"
    assert patched["target_minor"] == 800_000
    assert patched["icon"] == "kitchen"
    assert patched["color"] == GOAL_PAYLOAD["color"]


def test_patching_refuses_an_account_and_a_non_positive_target(client: TestClient) -> None:
    headers = register(client)
    goal_id = create_goal(client, headers)["id"]

    for payload in ({"account_id": "some-account"}, {"target_minor": 0}):
        response = client.patch(f"/api/v1/goals/{goal_id}", json=payload, headers=headers)
        assert response.status_code == 422, payload


# --- archiving ------------------------------------------------------------------------------


def test_deleting_archives_the_goal_and_hides_it_from_the_grid(client: TestClient) -> None:
    headers = register(client)
    kept = create_goal(client, headers, name="Voyage Japon")
    archived = create_goal(client, headers, name="Nouvelle cuisine")

    response = client.delete(f"/api/v1/goals/{archived['id']}", headers=headers)

    assert response.status_code == 204
    assert [goal["id"] for goal in list_goals(client, headers)] == [kept["id"]]
    assert [goal["id"] for goal in list_goals(client, headers, status="archived")] == [
        archived["id"]
    ]


def test_an_archived_goal_can_be_restored(client: TestClient) -> None:
    headers = register(client)
    goal_id = create_goal(client, headers)["id"]
    client.delete(f"/api/v1/goals/{goal_id}", headers=headers)

    response = client.patch(f"/api/v1/goals/{goal_id}", json={"status": "active"}, headers=headers)

    assert response.status_code == 200, response.json()
    assert response.json()["status"] == "active"
    assert [goal["id"] for goal in list_goals(client, headers)] == [goal_id]


def test_a_client_may_not_claim_reached(client: TestClient) -> None:
    """`reached` is arithmetic over the ledger, not something a payload asserts."""
    headers = register(client)
    goal_id = create_goal(client, headers)["id"]

    response = client.patch(f"/api/v1/goals/{goal_id}", json={"status": "reached"}, headers=headers)

    assert response.status_code == 422


# --- user scoping ---------------------------------------------------------------------------


def test_another_users_goal_is_not_found(client: TestClient) -> None:
    owner = register(client)
    other = register(client, email="bruno@example.com")
    goal_id = create_goal(client, owner)["id"]

    for method, url in (
        ("patch", f"/api/v1/goals/{goal_id}"),
        ("delete", f"/api/v1/goals/{goal_id}"),
    ):
        response = client.request(method.upper(), url, json={"name": "Vol"}, headers=other)
        assert response.status_code == 404, url
        assert response.json()["error"]["code"] == "GOAL_NOT_FOUND"

    assert list_goals(client, other) == []


def test_no_transaction_or_balance_is_written_by_a_goal(client: TestClient) -> None:
    headers = register(client)
    account = client.post(
        "/api/v1/accounts",
        json={
            "name": "Livret A",
            "type": "savings",
            "institution": "BNP Paribas",
            "opening_balance_minor": 2_210_000,
        },
        headers=headers,
    ).json()

    create_goal(client, headers, target_date=date(2028, 6, 1).isoformat())

    transactions = client.get("/api/v1/transactions", headers=headers).json()
    assert transactions["items"] == []
    unchanged = client.get(f"/api/v1/accounts/{account['id']}", headers=headers).json()
    assert unchanged["balance_minor"] == 2_210_000
