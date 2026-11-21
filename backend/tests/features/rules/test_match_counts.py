"""Tests for GET /rules/match-counts: the « Correspondances » column of the rules table."""

from pathlib import Path

from fastapi.testclient import TestClient

from tests.features.rules.test_rules import (
    _create_account,
    _create_category,
    _create_rule,
    _fetch_transaction,
    _insert_transaction,
    _register,
)

FIXTURES = Path(__file__).resolve().parent.parent.parent / "fixtures" / "imports"


def _counts(client: TestClient, headers: dict[str, str]) -> dict[str, int]:
    response = client.get("/api/v1/rules/match-counts", headers=headers)
    assert response.status_code == 200
    return {entry["rule_id"]: entry["match_count"] for entry in response.json()}


def test_counts_the_rows_each_rule_classed(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    grocer = _create_rule(client, headers, category_id, priority=1, pattern="CARREFOUR")
    train = _create_rule(client, headers, category_id, priority=2, pattern="SNCF")
    _insert_transaction(tmp_path, user_id, account_id, "CB CARREFOUR CITY")
    _insert_transaction(tmp_path, user_id, account_id, "CARREFOUR MARKET", amount_minor=-2500)
    _insert_transaction(tmp_path, user_id, account_id, "CAFE DU PORT", amount_minor=-350)
    client.post("/api/v1/rules/apply", json={}, headers=headers)

    assert _counts(client, headers) == {grocer["id"]: 2, train["id"]: 0}


def test_first_match_wins_and_hand_picked_rows_are_not_counted(
    client: TestClient, tmp_path: Path
) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    broad = _create_rule(client, headers, category_id, priority=1, pattern="CB")
    narrow = _create_rule(client, headers, category_id, priority=2, pattern="CARREFOUR")
    _insert_transaction(tmp_path, user_id, account_id, "CB CARREFOUR CITY")
    _insert_transaction(
        tmp_path,
        user_id,
        account_id,
        "CB BOULANGERIE",
        amount_minor=-450,
        category_id=category_id,
        categorization_source="user",
        needs_review=False,
    )
    client.post("/api/v1/rules/apply", json={}, headers=headers)

    assert _counts(client, headers) == {broad["id"]: 1, narrow["id"]: 0}


def test_a_disabled_rule_keeps_the_rows_it_classed(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    rule = _create_rule(client, headers, category_id, pattern="CARREFOUR")
    _insert_transaction(tmp_path, user_id, account_id, "CB CARREFOUR CITY")
    client.post("/api/v1/rules/apply", json={}, headers=headers)
    client.patch(f"/api/v1/rules/{rule['id']}", json={"enabled": False}, headers=headers)

    assert _counts(client, headers) == {rule["id"]: 1}


def test_a_rule_taking_over_with_the_same_category_moves_the_count_not_the_toast(
    client: TestClient, tmp_path: Path
) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    broad = _create_rule(client, headers, category_id, priority=2, pattern="CARREFOUR")
    transaction_id = _insert_transaction(tmp_path, user_id, account_id, "CB CARREFOUR CITY")
    client.post("/api/v1/rules/apply", json={}, headers=headers)
    narrow = _create_rule(client, headers, category_id, priority=1, pattern="CARREFOUR CITY")

    response = client.post("/api/v1/rules/apply", json={}, headers=headers)

    assert response.json()["recategorized_count"] == 0
    assert _fetch_transaction(tmp_path, transaction_id).rule_id == narrow["id"]
    assert _counts(client, headers) == {broad["id"]: 0, narrow["id"]: 1}


def test_a_hand_correction_takes_the_row_off_the_rule(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    rule = _create_rule(client, headers, category_id, pattern="CARREFOUR")
    transaction_id = _insert_transaction(tmp_path, user_id, account_id, "CB CARREFOUR CITY")
    client.post("/api/v1/rules/apply", json={}, headers=headers)
    other = client.post(
        "/api/v1/categories",
        json={"name": "Marchés", "kind": "expense", "icon": "store", "color": "cat2"},
        headers=headers,
    ).json()["id"]

    client.patch(
        f"/api/v1/transactions/{transaction_id}", json={"category_id": other}, headers=headers
    )

    assert _fetch_transaction(tmp_path, transaction_id).rule_id is None
    assert _counts(client, headers) == {rule["id"]: 0}


def test_deleting_a_rule_clears_the_attribution_and_keeps_the_category(
    client: TestClient, tmp_path: Path
) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    rule = _create_rule(client, headers, category_id, pattern="CARREFOUR")
    transaction_id = _insert_transaction(tmp_path, user_id, account_id, "CB CARREFOUR CITY")
    client.post("/api/v1/rules/apply", json={}, headers=headers)

    assert client.delete(f"/api/v1/rules/{rule['id']}", headers=headers).status_code == 204

    transaction = _fetch_transaction(tmp_path, transaction_id)
    assert transaction.rule_id is None
    assert transaction.category_id == category_id


def test_an_import_records_the_rule_that_classed_each_new_row(client: TestClient) -> None:
    headers, _ = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    rule = _create_rule(client, headers, category_id, pattern="SUPERMARCHE")

    with (FIXTURES / "sample_sgml.ofx").open("rb") as handle:
        response = client.post(
            "/api/v1/imports",
            headers=headers,
            data={"account_id": account_id},
            files={"file": ("sample_sgml.ofx", handle, "application/octet-stream")},
        )

    assert response.status_code in (200, 201), response.json()
    assert _counts(client, headers) == {rule["id"]: 1}


def test_counts_are_user_scoped(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    _create_rule(client, headers, category_id, pattern="CARREFOUR")
    _insert_transaction(tmp_path, user_id, account_id, "CB CARREFOUR CITY")
    client.post("/api/v1/rules/apply", json={}, headers=headers)

    other_headers, _ = _register(client, "basile@example.com")

    assert _counts(client, other_headers) == {}


def test_requires_authentication(client: TestClient) -> None:
    response = client.get("/api/v1/rules/match-counts")

    assert response.status_code == 401
    assert "error" in response.json()
