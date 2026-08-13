"""Tests for POST /rules/preview: the match count both rule editors show before committing."""

from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker

from app.features.rules.models import CategorizationRule
from app.features.transactions.models import Transaction
from tests.features.rules.test_rules import (
    ACCOUNT_PAYLOAD,
    _create_account,
    _create_category,
    _insert_transaction,
    _register,
)


def _preview(client: TestClient, headers: dict[str, str], **overrides: object) -> tuple[int, dict]:
    payload = {
        "match_field": "description_clean",
        "match_type": "contains",
        "pattern": "CARREFOUR",
        **overrides,
    }
    response = client.post("/api/v1/rules/preview", json=payload, headers=headers)
    return response.status_code, response.json()


def _apply_as_rule(
    client: TestClient, headers: dict[str, str], category_id: str, **overrides: object
) -> int:
    """Create the previewed rule for real and apply it; returns the rows it changed."""
    payload = {
        "priority": 1,
        "match_field": "description_clean",
        "match_type": "contains",
        "pattern": "CARREFOUR",
        "category_id": category_id,
        "enabled": True,
        **overrides,
    }
    client.post("/api/v1/rules", json=payload, headers=headers)
    response = client.post("/api/v1/rules/apply", json={}, headers=headers)
    return response.json()["recategorized_count"]


def _count_rules(tmp_path: Path) -> int:
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}", connect_args={"check_same_thread": False}
    )
    session = sessionmaker(bind=engine)()
    count = len(list(session.scalars(select(CategorizationRule))))
    session.close()
    return count


def _count_categorized(tmp_path: Path) -> int:
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}", connect_args={"check_same_thread": False}
    )
    session = sessionmaker(bind=engine)()
    rows = list(session.scalars(select(Transaction)))
    session.close()
    return len([row for row in rows if row.category_id is not None])


# --- the count agrees with a subsequent apply, per match type -------------------------------


def test_contains_preview_matches_what_apply_changes(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    _insert_transaction(tmp_path, user_id, account_id, "PAIEMENT CARREFOUR MARKET")
    _insert_transaction(tmp_path, user_id, account_id, "CB CARREFOUR CITY", amount_minor=-2500)
    _insert_transaction(tmp_path, user_id, account_id, "SNCF CONNECT", amount_minor=-4500)

    status_code, body = _preview(client, headers)

    assert status_code == 200
    assert body["match_count"] == 2
    assert _apply_as_rule(client, headers, category_id) == 2


def test_equals_preview_matches_what_apply_changes(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    _insert_transaction(tmp_path, user_id, account_id, "CARREFOUR")
    _insert_transaction(tmp_path, user_id, account_id, "CARREFOUR MARKET", amount_minor=-2500)

    _, body = _preview(client, headers, match_type="equals")

    assert body["match_count"] == 1
    assert _apply_as_rule(client, headers, category_id, match_type="equals") == 1


def test_regex_preview_matches_what_apply_changes(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    _insert_transaction(tmp_path, user_id, account_id, "CB CARREFOUR 4979")
    _insert_transaction(tmp_path, user_id, account_id, "CB CARREFOUR CITY", amount_minor=-2500)
    _insert_transaction(tmp_path, user_id, account_id, "SNCF 4979", amount_minor=-4500)

    _, body = _preview(client, headers, match_type="regex", pattern=r"CARREFOUR \d{4}")

    assert body["match_count"] == 1
    assert (
        _apply_as_rule(client, headers, category_id, match_type="regex", pattern=r"CARREFOUR \d{4}")
        == 1
    )


def test_range_preview_matches_what_apply_changes(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    _insert_transaction(tmp_path, user_id, account_id, "SALAIRE", amount_minor=285_000)
    _insert_transaction(tmp_path, user_id, account_id, "PRIME", amount_minor=120_000)
    _insert_transaction(tmp_path, user_id, account_id, "CAFE", amount_minor=-350)

    _, body = _preview(client, headers, match_field="amount", match_type="range", pattern="100000:")

    assert body["match_count"] == 2
    assert (
        _apply_as_rule(
            client,
            headers,
            category_id,
            match_field="amount",
            match_type="range",
            pattern="100000:",
        )
        == 2
    )


# --- samples --------------------------------------------------------------------------------


def test_preview_returns_at_most_three_samples(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    for index in range(5):
        _insert_transaction(
            tmp_path, user_id, account_id, "CB CARREFOUR CITY", amount_minor=-100 * (index + 1)
        )

    _, body = _preview(client, headers)

    assert body["match_count"] == 5
    assert len(body["samples"]) == 3
    assert all("CARREFOUR" in sample["description_clean"] for sample in body["samples"])


def test_preview_samples_carry_the_transaction_shape(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    _insert_transaction(tmp_path, user_id, account_id, "CB CARREFOUR CITY", amount_minor=-2500)

    _, body = _preview(client, headers)

    sample = body["samples"][0]
    assert sample["amount_minor"] == -2500
    assert sample["booked_date"] == "2026-01-15"
    assert sample["category"] is None


def test_preview_with_no_match_returns_zero_and_no_samples(client: TestClient) -> None:
    headers, _ = _register(client)
    _create_account(client, headers)

    _, body = _preview(client, headers)

    assert body == {"match_count": 0, "samples": []}


# --- scoping, validation, and persistence ---------------------------------------------------


def test_preview_scopes_to_the_given_account(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id_a = _create_account(client, headers)
    account_id_b = client.post(
        "/api/v1/accounts", json={**ACCOUNT_PAYLOAD, "name": "Livret A"}, headers=headers
    ).json()["id"]
    _insert_transaction(tmp_path, user_id, account_id_a, "CB CARREFOUR CITY")
    _insert_transaction(tmp_path, user_id, account_id_b, "CB CARREFOUR CITY", amount_minor=-2500)

    _, both = _preview(client, headers)
    _, one = _preview(client, headers, account_id=account_id_a)

    assert both["match_count"] == 2
    assert one["match_count"] == 1


def test_preview_never_counts_another_users_transactions(
    client: TestClient, tmp_path: Path
) -> None:
    headers_a, _ = _register(client, "amelie@example.com")
    _create_account(client, headers_a)
    headers_b, user_id_b = _register(client, "bruno@example.com")
    account_id_b = _create_account(client, headers_b)
    _insert_transaction(tmp_path, user_id_b, account_id_b, "CB CARREFOUR CITY")

    _, body_a = _preview(client, headers_a)
    _, body_b = _preview(client, headers_b)

    assert body_a["match_count"] == 0
    assert body_b["match_count"] == 1


def test_preview_rejects_an_uncompilable_regex(client: TestClient) -> None:
    headers, _ = _register(client)

    status_code, body = _preview(client, headers, match_type="regex", pattern="CARREFOUR(")

    assert status_code == 422
    assert body["error"]["code"] == "RULE_PATTERN_INVALID"
    assert "missing ), unterminated subpattern" in body["error"]["details"]["error"]


def test_preview_requires_auth(client: TestClient) -> None:
    response = client.post(
        "/api/v1/rules/preview",
        json={"match_field": "merchant", "match_type": "equals", "pattern": "CARREFOUR"},
    )

    assert response.status_code == 401


def test_preview_persists_nothing(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    _insert_transaction(tmp_path, user_id, account_id, "CB CARREFOUR CITY")

    _, body = _preview(client, headers)

    assert body["match_count"] == 1
    assert _count_rules(tmp_path) == 0
    assert _count_categorized(tmp_path) == 0
    assert client.get("/api/v1/rules", headers=headers).json() == []
