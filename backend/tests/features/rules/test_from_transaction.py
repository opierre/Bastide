"""Tests for POST /rules/from-transaction: the learning loop, correction → rule."""

from datetime import date
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.features.accounts.models import Account
from app.features.auth.models import User
from app.features.categories.models import Category
from app.features.categories.repository import CategoryRepository
from app.features.categories.service import CategoryNotFoundError
from app.features.imports.models import ImportBatch
from app.features.rules.models import CategorizationRule
from app.features.rules.repository import RuleRepository
from app.features.rules.schemas import RuleFromTransactionRequest
from app.features.rules.service import RuleService
from app.features.transactions.models import Transaction
from app.features.transactions.repository import TransactionRepository
from tests.features.rules.test_rules import (
    _create_account,
    _create_category,
    _create_rule,
    _fetch_transaction,
    _insert_transaction,
    _register,
)


def _from_transaction(
    client: TestClient,
    headers: dict[str, str],
    transaction_id: str,
    category_id: str,
    **overrides: object,
) -> tuple[int, dict]:
    payload = {
        "transaction_id": transaction_id,
        "match_field": "description_clean",
        "match_type": "contains",
        "pattern": "CARREFOUR",
        "category_id": category_id,
        "apply_now": True,
        **overrides,
    }
    response = client.post("/api/v1/rules/from-transaction", json=payload, headers=headers)
    return response.status_code, response.json()


# --- the happy path -------------------------------------------------------------------------


def test_creates_the_rule_and_corrects_the_source_transaction(
    client: TestClient, tmp_path: Path
) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    transaction_id = _insert_transaction(tmp_path, user_id, account_id, "PRLV CARREFOUR BANQUE")

    status_code, body = _from_transaction(
        client, headers, transaction_id, category_id, apply_now=False
    )

    assert status_code == 201
    assert body["rule"]["pattern"] == "CARREFOUR"
    assert body["rule"]["category_id"] == category_id
    assert body["rule"]["enabled"] is True

    transaction = _fetch_transaction(tmp_path, transaction_id)
    assert transaction.category_id == category_id
    assert transaction.categorization_source == "user"
    assert transaction.needs_review is False


def test_a_system_category_is_a_valid_target(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    system_category_id = next(
        category["id"]
        for category in client.get("/api/v1/categories", headers=headers).json()
        if category["is_system"]
    )
    transaction_id = _insert_transaction(tmp_path, user_id, account_id, "PRLV CARREFOUR BANQUE")

    status_code, body = _from_transaction(
        client, headers, transaction_id, system_category_id, apply_now=False
    )

    assert status_code == 201
    assert body["rule"]["category_id"] == system_category_id


# --- priority -------------------------------------------------------------------------------


def test_a_learned_rule_lands_last_in_priority_order(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    _create_rule(client, headers, category_id, priority=3, pattern="SNCF")
    _create_rule(client, headers, category_id, priority=7, pattern="EDF")
    transaction_id = _insert_transaction(tmp_path, user_id, account_id, "PRLV CARREFOUR BANQUE")

    _, body = _from_transaction(client, headers, transaction_id, category_id, apply_now=False)

    assert body["rule"]["priority"] == 8
    listed = client.get("/api/v1/rules", headers=headers).json()
    assert [rule["pattern"] for rule in listed] == ["SNCF", "EDF", "CARREFOUR"]


def test_the_first_learned_rule_starts_the_priority_order(
    client: TestClient, tmp_path: Path
) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    transaction_id = _insert_transaction(tmp_path, user_id, account_id, "PRLV CARREFOUR BANQUE")

    _, body = _from_transaction(client, headers, transaction_id, category_id, apply_now=False)

    assert body["rule"]["priority"] == 1


# --- apply_now ------------------------------------------------------------------------------


def test_apply_now_recategorizes_matching_rows_and_reports_the_count(
    client: TestClient, tmp_path: Path
) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    transaction_id = _insert_transaction(tmp_path, user_id, account_id, "PRLV CARREFOUR BANQUE")
    other_id = _insert_transaction(
        tmp_path, user_id, account_id, "CB CARREFOUR CITY", amount_minor=-2500
    )
    untouched_id = _insert_transaction(
        tmp_path, user_id, account_id, "SNCF CONNECT", amount_minor=-4500
    )

    _, body = _from_transaction(client, headers, transaction_id, category_id, apply_now=True)

    # The source row is already `source=user`, so the apply step reports only the other match.
    assert body["recategorized_count"] == 1

    other = _fetch_transaction(tmp_path, other_id)
    assert other.category_id == category_id
    assert other.categorization_source == "rule"
    assert other.needs_review is False

    untouched = _fetch_transaction(tmp_path, untouched_id)
    assert untouched.category_id is None
    assert untouched.categorization_source == "uncategorized"


def test_apply_now_false_changes_nothing_beyond_the_source_row(
    client: TestClient, tmp_path: Path
) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    transaction_id = _insert_transaction(tmp_path, user_id, account_id, "PRLV CARREFOUR BANQUE")
    other_id = _insert_transaction(
        tmp_path, user_id, account_id, "CB CARREFOUR CITY", amount_minor=-2500
    )

    _, body = _from_transaction(client, headers, transaction_id, category_id, apply_now=False)

    assert body["recategorized_count"] == 0
    other = _fetch_transaction(tmp_path, other_id)
    assert other.category_id is None
    assert other.categorization_source == "uncategorized"
    assert other.needs_review is True


def test_apply_now_never_overrides_a_user_categorized_row(
    client: TestClient, tmp_path: Path
) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    kept_category_id = _create_category(client, headers)
    transaction_id = _insert_transaction(tmp_path, user_id, account_id, "PRLV CARREFOUR BANQUE")
    protected_id = _insert_transaction(
        tmp_path,
        user_id,
        account_id,
        "CB CARREFOUR CITY",
        amount_minor=-2500,
        category_id=kept_category_id,
        categorization_source="user",
        needs_review=False,
    )

    _, body = _from_transaction(client, headers, transaction_id, category_id, apply_now=True)

    assert body["recategorized_count"] == 0
    protected = _fetch_transaction(tmp_path, protected_id)
    assert protected.category_id == kept_category_id
    assert protected.categorization_source == "user"


# --- validation and scoping -----------------------------------------------------------------


def test_an_uncompilable_regex_is_rejected(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    category_id = _create_category(client, headers)
    transaction_id = _insert_transaction(tmp_path, user_id, account_id, "PRLV CARREFOUR BANQUE")

    status_code, body = _from_transaction(
        client,
        headers,
        transaction_id,
        category_id,
        match_type="regex",
        pattern="CARREFOUR(",
    )

    assert status_code == 422
    assert body["error"]["code"] == "RULE_PATTERN_INVALID"
    assert "missing ), unterminated subpattern" in body["error"]["details"]["error"]

    # A rejected pattern creates nothing and corrects nothing.
    assert client.get("/api/v1/rules", headers=headers).json() == []
    assert _fetch_transaction(tmp_path, transaction_id).category_id is None


def test_another_users_transaction_is_a_404(client: TestClient, tmp_path: Path) -> None:
    headers_a, _ = _register(client, "amelie@example.com")
    category_id_a = _create_category(client, headers_a)
    headers_b, user_id_b = _register(client, "bruno@example.com")
    account_id_b = _create_account(client, headers_b)
    transaction_id_b = _insert_transaction(
        tmp_path, user_id_b, account_id_b, "PRLV CARREFOUR BANQUE"
    )

    status_code, body = _from_transaction(client, headers_a, transaction_id_b, category_id_a)

    assert status_code == 404
    assert body["error"]["code"] == "TRANSACTION_NOT_FOUND"
    assert client.get("/api/v1/rules", headers=headers_a).json() == []


def test_another_users_category_is_a_404(client: TestClient, tmp_path: Path) -> None:
    headers_a, user_id_a = _register(client, "amelie@example.com")
    account_id_a = _create_account(client, headers_a)
    transaction_id_a = _insert_transaction(
        tmp_path, user_id_a, account_id_a, "PRLV CARREFOUR BANQUE"
    )
    headers_b, _ = _register(client, "bruno@example.com")
    category_id_b = _create_category(client, headers_b)

    status_code, body = _from_transaction(client, headers_a, transaction_id_a, category_id_b)

    assert status_code == 404
    assert body["error"]["code"] == "CATEGORY_NOT_FOUND"
    assert client.get("/api/v1/rules", headers=headers_a).json() == []
    assert _fetch_transaction(tmp_path, transaction_id_a).category_id is None


def test_from_transaction_requires_auth(client: TestClient) -> None:
    response = client.post(
        "/api/v1/rules/from-transaction",
        json={
            "transaction_id": "t-1",
            "match_field": "merchant",
            "match_type": "equals",
            "pattern": "CARREFOUR",
            "category_id": "c-1",
            "apply_now": False,
        },
    )

    assert response.status_code == 401


# --- atomicity ------------------------------------------------------------------------------


def _seed(db_session: Session) -> tuple[str, str, str]:
    """A user with one account, one category, and one uncategorized transaction."""
    user = User(
        email="amelie@example.com",
        password_hash="hash",
        display_name="Amelie",
        locale="fr",
        currency="EUR",
    )
    db_session.add(user)
    db_session.flush()
    account = Account(
        user_id=user.id,
        name="Compte courant",
        type="checking",
        institution="BNP Paribas",
        currency="EUR",
        opening_balance_minor=100_000,
        cached_balance_minor=100_000,
    )
    category = Category(
        user_id=user.id, name="Courses", kind="expense", icon="shopping_cart", color="#10B981"
    )
    db_session.add_all([account, category])
    db_session.flush()
    batch = ImportBatch(
        user_id=user.id,
        account_id=account.id,
        source_format="csv",
        file_name="test.csv",
        file_hash="hash",
        period_start=date(2026, 1, 1),
        period_end=date(2026, 1, 31),
        transaction_count=1,
        new_count=1,
        duplicate_count=0,
        status="success",
    )
    db_session.add(batch)
    db_session.flush()
    transaction = Transaction(
        account_id=account.id,
        import_batch_id=batch.id,
        booked_date=date(2026, 1, 15),
        amount_minor=-1000,
        currency="EUR",
        description_raw="PRLV CARREFOUR BANQUE",
        description_clean="PRLV CARREFOUR BANQUE",
        categorization_source="uncategorized",
        needs_review=True,
        dedup_hash="dedup-1",
    )
    db_session.add(transaction)
    db_session.commit()
    return user.id, category.id, transaction.id


def test_the_rule_and_the_correction_roll_back_together(db_session: Session) -> None:
    user_id, category_id, transaction_id = _seed(db_session)
    service = RuleService(
        RuleRepository(db_session),
        TransactionRepository(db_session),
        CategoryRepository(db_session),
        db_session,
    )

    def failing_commit(*args: Any, **kwargs: Any) -> None:
        raise RuntimeError("disk full")

    db_session.commit = failing_commit  # ty: ignore[invalid-assignment] — induced failure

    with pytest.raises(RuntimeError):
        service.create_from_transaction(
            user_id,
            RuleFromTransactionRequest(
                transaction_id=transaction_id,
                match_field="description_clean",
                match_type="contains",
                pattern="CARREFOUR",
                category_id=category_id,
                apply_now=False,
            ),
        )

    del db_session.commit  # restore the real commit for the assertions below
    assert list(db_session.scalars(select(CategorizationRule))) == []
    transaction = db_session.get(Transaction, transaction_id)
    assert transaction is not None
    assert transaction.category_id is None
    assert transaction.categorization_source == "uncategorized"
    assert transaction.needs_review is True


def test_a_missing_category_raises_before_anything_is_staged(db_session: Session) -> None:
    user_id, _, transaction_id = _seed(db_session)
    service = RuleService(
        RuleRepository(db_session),
        TransactionRepository(db_session),
        CategoryRepository(db_session),
        db_session,
    )

    with pytest.raises(CategoryNotFoundError):
        service.create_from_transaction(
            user_id,
            RuleFromTransactionRequest(
                transaction_id=transaction_id,
                match_field="description_clean",
                match_type="contains",
                pattern="CARREFOUR",
                category_id="does-not-exist",
                apply_now=False,
            ),
        )

    assert list(db_session.scalars(select(CategorizationRule))) == []
    transaction = db_session.get(Transaction, transaction_id)
    assert transaction is not None
    assert transaction.categorization_source == "uncategorized"
