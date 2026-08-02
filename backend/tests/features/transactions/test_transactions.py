"""Tests for the transaction list endpoint: filters, search, and pagination."""

from datetime import date
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.features.accounts.models import Account
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

_counter = 0


def _next_unique() -> int:
    global _counter
    _counter += 1
    return _counter


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


def _create_account(client: TestClient, headers: dict[str, str], **overrides: object) -> str:
    response = client.post(
        "/api/v1/accounts", json={**ACCOUNT_PAYLOAD, **overrides}, headers=headers
    )
    return response.json()["id"]


def _create_category(client: TestClient, headers: dict[str, str], **overrides: object) -> str:
    response = client.post(
        "/api/v1/categories", json={**CATEGORY_PAYLOAD, **overrides}, headers=headers
    )
    return response.json()["id"]


def _insert_transaction(
    tmp_path: Path,
    account_id: str,
    *,
    booked_date: date = date(2026, 1, 15),
    description_clean: str = "PAIEMENT CARREFOUR MARKET",
    merchant: str | None = None,
    amount_minor: int = -1000,
    category_id: str | None = None,
    categorization_source: str = "uncategorized",
    needs_review: bool = True,
) -> str:
    """Insert a transaction straight into the client's SQLite file (no import pipeline here)."""
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}", connect_args={"check_same_thread": False}
    )
    session = sessionmaker(bind=engine)()
    unique = f"{_next_unique()}-{description_clean}-{amount_minor}-{booked_date.isoformat()}"
    batch = ImportBatch(
        user_id=_account_user_id(session, account_id),
        account_id=account_id,
        source_format="csv",
        file_name="test.csv",
        file_hash=f"hash-{unique}",
        period_start=booked_date,
        period_end=booked_date,
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
        booked_date=booked_date,
        amount_minor=amount_minor,
        currency="EUR",
        description_raw=description_clean,
        description_clean=description_clean,
        merchant=merchant,
        category_id=category_id,
        categorization_source=categorization_source,
        needs_review=needs_review,
        dedup_hash=f"dedup-{unique}",
    )
    session.add(transaction)
    session.commit()
    transaction_id = transaction.id
    session.close()
    return transaction_id


def _account_user_id(session: Session, account_id: str) -> str:
    account = session.get(Account, account_id)
    assert account is not None
    return account.user_id


# --- list: filters, search, pagination ------------------------------------------------------


def test_list_transactions_returns_own_transactions(client: TestClient, tmp_path: Path) -> None:
    headers, _ = _register(client)
    account_id = _create_account(client, headers)
    _insert_transaction(tmp_path, account_id)

    response = client.get("/api/v1/transactions", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 1
    assert body["page"] == 1
    assert len(body["items"]) == 1


def test_list_filters_by_account(client: TestClient, tmp_path: Path) -> None:
    headers, _ = _register(client)
    account_id_a = _create_account(client, headers)
    account_id_b = _create_account(client, headers, name="Livret A")
    _insert_transaction(tmp_path, account_id_a)
    _insert_transaction(tmp_path, account_id_b)

    response = client.get(
        "/api/v1/transactions", params={"account_id": account_id_a}, headers=headers
    )

    body = response.json()
    assert body["total"] == 1
    assert body["items"][0]["account_id"] == account_id_a


def test_list_filters_by_date_range(client: TestClient, tmp_path: Path) -> None:
    headers, _ = _register(client)
    account_id = _create_account(client, headers)
    _insert_transaction(tmp_path, account_id, booked_date=date(2026, 1, 5))
    _insert_transaction(tmp_path, account_id, booked_date=date(2026, 2, 5))

    response = client.get(
        "/api/v1/transactions",
        params={"from": "2026-01-01", "to": "2026-01-31"},
        headers=headers,
    )

    body = response.json()
    assert body["total"] == 1
    assert body["items"][0]["booked_date"] == "2026-01-05"


def test_list_filters_by_category(client: TestClient, tmp_path: Path) -> None:
    headers, _ = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    _insert_transaction(
        tmp_path,
        account_id,
        category_id=category_id,
        categorization_source="user",
        needs_review=False,
    )
    _insert_transaction(tmp_path, account_id)

    response = client.get(
        "/api/v1/transactions", params={"category_id": category_id}, headers=headers
    )

    body = response.json()
    assert body["total"] == 1
    assert body["items"][0]["category"]["id"] == category_id


def test_list_filters_by_needs_review(client: TestClient, tmp_path: Path) -> None:
    headers, _ = _register(client)
    account_id = _create_account(client, headers)
    _insert_transaction(tmp_path, account_id, needs_review=True)
    _insert_transaction(tmp_path, account_id, needs_review=False, categorization_source="user")

    response = client.get("/api/v1/transactions", params={"needs_review": "true"}, headers=headers)

    body = response.json()
    assert body["total"] == 1
    assert body["items"][0]["needs_review"] is True


def test_list_search_matches_description_and_merchant(client: TestClient, tmp_path: Path) -> None:
    headers, _ = _register(client)
    account_id = _create_account(client, headers)
    _insert_transaction(tmp_path, account_id, description_clean="PAIEMENT CARREFOUR MARKET")
    _insert_transaction(
        tmp_path, account_id, description_clean="VIREMENT SALAIRE", merchant="ACME Corp"
    )

    response = client.get("/api/v1/transactions", params={"q": "carrefour"}, headers=headers)
    assert response.json()["total"] == 1

    response = client.get("/api/v1/transactions", params={"q": "acme"}, headers=headers)
    assert response.json()["total"] == 1


def test_list_filters_compose(client: TestClient, tmp_path: Path) -> None:
    headers, _ = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    _insert_transaction(
        tmp_path,
        account_id,
        description_clean="PAIEMENT CARREFOUR MARKET",
        category_id=category_id,
        categorization_source="user",
        needs_review=False,
    )
    _insert_transaction(tmp_path, account_id, description_clean="PAIEMENT CARREFOUR DRIVE")

    response = client.get(
        "/api/v1/transactions",
        params={"q": "carrefour", "category_id": category_id},
        headers=headers,
    )

    assert response.json()["total"] == 1


def test_list_pagination_is_stable_and_bounded(client: TestClient, tmp_path: Path) -> None:
    headers, _ = _register(client)
    account_id = _create_account(client, headers)
    for i in range(60):
        _insert_transaction(
            tmp_path, account_id, description_clean=f"TX {i}", booked_date=date(2026, 1, 1)
        )

    page_1 = client.get("/api/v1/transactions", headers=headers).json()
    assert page_1["total"] == 60
    assert len(page_1["items"]) == page_1["page_size"]
    assert page_1["page_size"] <= 50

    page_2 = client.get("/api/v1/transactions", params={"page": 2}, headers=headers).json()
    assert len(page_2["items"]) == 60 - page_1["page_size"]

    ids_page_1 = {item["id"] for item in page_1["items"]}
    ids_page_2 = {item["id"] for item in page_2["items"]}
    assert ids_page_1.isdisjoint(ids_page_2)


def test_list_requires_auth(client: TestClient) -> None:
    response = client.get("/api/v1/transactions")
    assert response.status_code == 401


def test_list_is_user_scoped(client: TestClient, tmp_path: Path) -> None:
    headers_a, _ = _register(client, "amelie@example.com")
    account_id_a = _create_account(client, headers_a)
    _insert_transaction(tmp_path, account_id_a)

    headers_b, _ = _register(client, "bruno@example.com")
    account_id_b = _create_account(client, headers_b)
    _insert_transaction(tmp_path, account_id_b)

    response = client.get("/api/v1/transactions", headers=headers_a)
    assert response.json()["total"] == 1
