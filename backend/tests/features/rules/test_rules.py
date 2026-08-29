"""Tests for rule CRUD and the /rules/apply re-categorization endpoint."""

from datetime import date
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.features.imports.models import ImportBatch
from app.features.transactions.models import Transaction

ACCOUNT_PAYLOAD = {
    "name": "Compte courant",
    "type": "checking",
    "institution": "BNP Paribas",
    "opening_balance_minor": 100_000,
}

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


def _register(client: TestClient, email: str = "amelie@example.com") -> tuple[dict[str, str], str]:
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
    body = response.json()
    return {"Authorization": f"Bearer {body['token']}"}, body["user"]["id"]


def _create_account(client: TestClient, headers: dict[str, str]) -> str:
    response = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers)
    return response.json()["id"]


def _create_category(client: TestClient, headers: dict[str, str]) -> str:
    response = client.post("/api/v1/categories", json=CATEGORY_PAYLOAD, headers=headers)
    return response.json()["id"]


def _create_rule(
    client: TestClient, headers: dict[str, str], category_id: str, **overrides: object
) -> dict:
    payload = {**RULE_PAYLOAD, "category_id": category_id, **overrides}
    response = client.post("/api/v1/rules", json=payload, headers=headers)
    return response.json()


def _insert_transaction(
    tmp_path: Path,
    user_id: str,
    account_id: str,
    description_clean: str,
    amount_minor: int = -1000,
    category_id: str | None = None,
    categorization_source: str = "uncategorized",
    needs_review: bool = True,
) -> str:
    """Insert a transaction straight into the client's SQLite file (no transactions API yet)."""
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}", connect_args={"check_same_thread": False}
    )
    session = sessionmaker(bind=engine)()
    batch = ImportBatch(
        user_id=user_id,
        account_id=account_id,
        source_format="csv",
        file_name="test.csv",
        file_hash=f"hash-{description_clean}-{amount_minor}",
        period_start=date(2026, 1, 1),
        period_end=date(2026, 1, 1),
        transaction_count=1,
        new_count=1,
        duplicate_count=0,
        status="success",
    )
    session.add(batch)
    session.flush()
    transaction = Transaction(
        account_id=account_id,
        import_batch_id=batch.id,
        booked_date=date(2026, 1, 15),
        amount_minor=amount_minor,
        currency="EUR",
        description_raw=description_clean,
        description_clean=description_clean,
        category_id=category_id,
        categorization_source=categorization_source,
        needs_review=needs_review,
        dedup_hash=f"dedup-{description_clean}-{amount_minor}",
    )
    session.add(transaction)
    session.commit()
    transaction_id = transaction.id
    session.close()
    return transaction_id


def _fetch_transaction(tmp_path: Path, transaction_id: str) -> Transaction:
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}", connect_args={"check_same_thread": False}
    )
    session = sessionmaker(bind=engine)()
    transaction = session.get(Transaction, transaction_id)
    assert transaction is not None
    session.expunge(transaction)
    session.close()
    return transaction


# --- CRUD --------------------------------------------------------------------------------


def test_create_rule(client: TestClient) -> None:
    headers, _ = _register(client)
    category_id = _create_category(client, headers)

    rule = _create_rule(client, headers, category_id)

    assert rule["priority"] == 1
    assert rule["match_field"] == "description_clean"
    assert rule["match_type"] == "contains"
    assert rule["pattern"] == "CARREFOUR"
    assert rule["category_id"] == category_id
    assert rule["enabled"] is True


def test_list_rules_in_priority_order(client: TestClient) -> None:
    headers, _ = _register(client)
    category_id = _create_category(client, headers)
    _create_rule(client, headers, category_id, priority=2, pattern="B")
    _create_rule(client, headers, category_id, priority=1, pattern="A")

    response = client.get("/api/v1/rules", headers=headers)

    body = response.json()
    assert [r["priority"] for r in body] == [1, 2]


def test_update_rule(client: TestClient) -> None:
    headers, _ = _register(client)
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
    headers, _ = _register(client)
    category_id = _create_category(client, headers)
    rule = _create_rule(client, headers, category_id)

    response = client.delete(f"/api/v1/rules/{rule['id']}", headers=headers)
    assert response.status_code == 204

    list_response = client.get("/api/v1/rules", headers=headers)
    assert list_response.json() == []


def test_cross_user_rule_access_returns_404(client: TestClient) -> None:
    headers_a, _ = _register(client, "amelie@example.com")
    category_id = _create_category(client, headers_a)
    rule = _create_rule(client, headers_a, category_id)

    headers_b, _ = _register(client, "bruno@example.com")
    response = client.patch(f"/api/v1/rules/{rule['id']}", json={"priority": 9}, headers=headers_b)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "RULE_NOT_FOUND"


def test_rules_require_auth(client: TestClient) -> None:
    response = client.get("/api/v1/rules")

    assert response.status_code == 401


# --- apply ---------------------------------------------------------------------------------


def test_apply_recategorizes_matching_transactions(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    _create_rule(client, headers, category_id)

    transaction_id = _insert_transaction(tmp_path, user_id, account_id, "PAIEMENT CARREFOUR MARKET")

    response = client.post("/api/v1/rules/apply", json={}, headers=headers)

    assert response.status_code == 200
    assert response.json()["recategorized_count"] == 1

    transaction = _fetch_transaction(tmp_path, transaction_id)
    assert transaction.category_id == category_id
    assert transaction.categorization_source == "rule"
    assert transaction.needs_review is False


def test_apply_skips_non_matching_transactions(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    _create_rule(client, headers, category_id)

    transaction_id = _insert_transaction(tmp_path, user_id, account_id, "SOMETHING ELSE ENTIRELY")

    response = client.post("/api/v1/rules/apply", json={}, headers=headers)

    assert response.json()["recategorized_count"] == 0
    transaction = _fetch_transaction(tmp_path, transaction_id)
    assert transaction.category_id is None
    assert transaction.categorization_source == "uncategorized"
    assert transaction.needs_review is True


def test_apply_never_overrides_user_source(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    _create_rule(client, headers, category_id)

    user_category_id = _create_category(client, headers)
    transaction_id = _insert_transaction(
        tmp_path,
        user_id,
        account_id,
        "PAIEMENT CARREFOUR MARKET",
        category_id=user_category_id,
        categorization_source="user",
        needs_review=False,
    )

    response = client.post("/api/v1/rules/apply", json={}, headers=headers)

    assert response.json()["recategorized_count"] == 0
    transaction = _fetch_transaction(tmp_path, transaction_id)
    assert transaction.category_id == user_category_id
    assert transaction.categorization_source == "user"


def test_apply_scopes_to_given_account(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id_a = _create_account(client, headers)
    account_id_b = client.post(
        "/api/v1/accounts",
        json={**ACCOUNT_PAYLOAD, "name": "Livret A"},
        headers=headers,
    ).json()["id"]
    category_id = _create_category(client, headers)
    _create_rule(client, headers, category_id)

    _insert_transaction(tmp_path, user_id, account_id_a, "PAIEMENT CARREFOUR MARKET")
    _insert_transaction(tmp_path, user_id, account_id_b, "PAIEMENT CARREFOUR MARKET")

    response = client.post(
        "/api/v1/rules/apply", json={"account_id": account_id_a}, headers=headers
    )

    assert response.json()["recategorized_count"] == 1


def test_apply_is_user_scoped(client: TestClient, tmp_path: Path) -> None:
    headers_a, _ = _register(client, "amelie@example.com")
    _create_account(client, headers_a)
    category_id_a = _create_category(client, headers_a)
    _create_rule(client, headers_a, category_id_a)

    headers_b, user_id_b = _register(client, "bruno@example.com")
    account_id_b = _create_account(client, headers_b)

    _insert_transaction(tmp_path, user_id_b, account_id_b, "PAIEMENT CARREFOUR MARKET")

    response_a = client.post("/api/v1/rules/apply", json={}, headers=headers_a)
    assert response_a.json()["recategorized_count"] == 0

    response_b = client.post("/api/v1/rules/apply", json={}, headers=headers_b)
    assert response_b.json()["recategorized_count"] == 0


def test_create_rejects_a_regex_that_does_not_compile(client: TestClient) -> None:
    """The preview already refused it; saving must refuse it too.

    Without this the modal shows the pattern error and the save still succeeds, and the
    uncompilable rule only surfaces later as a 500 out of `/rules/apply` — from a screen that
    never mentioned a pattern.
    """
    headers, _ = _register(client)
    category_id = _create_category(client, headers)

    response = client.post(
        "/api/v1/rules",
        json={
            **RULE_PAYLOAD,
            "category_id": category_id,
            "match_type": "regex",
            "pattern": "CARREFOUR(",
        },
        headers=headers,
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "RULE_PATTERN_INVALID"
    assert client.get("/api/v1/rules", headers=headers).json() == []


def test_update_rejects_a_regex_the_patch_would_produce(client: TestClient) -> None:
    """Checked against the resulting rule, not the patch body.

    Switching `match_type` to `regex` without resending `pattern` is what turns a stored
    `contains` string into an uncompilable expression, and the patch alone looks harmless.
    """
    headers, _ = _register(client)
    category_id = _create_category(client, headers)
    rule = _create_rule(client, headers, category_id, pattern="CARREFOUR(")

    response = client.patch(
        f"/api/v1/rules/{rule['id']}", json={"match_type": "regex"}, headers=headers
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "RULE_PATTERN_INVALID"
    assert client.get("/api/v1/rules", headers=headers).json()[0]["match_type"] == "contains"
