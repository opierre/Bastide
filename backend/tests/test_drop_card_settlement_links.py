"""Tests for the migration retiring settlement-to-cycle matching (c5a9d2f7e381)."""

import hashlib
from datetime import date
from pathlib import Path
from uuid import uuid4

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import Session

from app.features.accounts.models import Account
from app.features.auth.models import User
from app.features.imports.models import ImportBatch
from app.features.transactions.models import Transaction
from tests.migrations import upgrade

PRE_MIGRATION_REVISION = "b3f6e8a1c5d7"


def _row(account: Account, batch: ImportBatch, amount_minor: int, label: str) -> Transaction:
    return Transaction(
        account_id=account.id,
        import_batch_id=batch.id,
        booked_date=date(2026, 1, 31),
        amount_minor=amount_minor,
        currency="EUR",
        description_raw=label,
        description_clean=label,
        categorization_source="uncategorized",
        needs_review=False,
        dedup_hash=str(uuid4()),
    )


def test_posted_credits_go_and_proposals_return_to_review(tmp_path: Path) -> None:
    db_path = tmp_path / "bastide.db"
    upgrade(db_path, PRE_MIGRATION_REVISION)
    engine = create_engine(f"sqlite:///{db_path}")
    with Session(engine) as db:
        user = User(
            email="camille@example.test",
            password_hash="hash",
            display_name="camille",
            locale="fr",
            currency="EUR",
        )
        db.add(user)
        db.flush()
        checking = Account(
            user_id=user.id,
            name="Courant",
            type="checking",
            institution="Banque",
            currency="EUR",
            opening_balance_minor=0,
            cached_balance_minor=-45_210,
        )
        card = Account(
            user_id=user.id,
            name="Carte",
            type="deferred_card",
            institution="Banque",
            currency="EUR",
            opening_balance_minor=0,
            cached_balance_minor=0,
        )
        db.add_all([checking, card])
        db.flush()
        batch = ImportBatch(
            user_id=user.id,
            account_id=checking.id,
            source_format="ofx",
            file_name="releve.ofx",
            file_hash="h",
            period_start=date(2026, 1, 1),
            period_end=date(2026, 1, 31),
            transaction_count=1,
            new_count=1,
            duplicate_count=0,
            status="success",
        )
        db.add(batch)
        db.flush()
        settlement = _row(checking, batch, -45_210, "FACTURE CARTE")
        settlement.categorization_source = "detected"
        settlement.needs_review = True
        purchase = _row(card, batch, -45_210, "FNAC")
        db.add_all([settlement, purchase])
        db.flush()
        posted = _row(card, batch, 45_210, "FACTURE CARTE")
        posted.dedup_hash = hashlib.sha256(f"card-settlement:{settlement.id}".encode()).hexdigest()
        db.add(posted)
        db.commit()
        ids = {"settlement": settlement.id, "purchase": purchase.id, "posted": posted.id}
        card_id = card.id
        with engine.begin() as connection:
            connection.execute(
                text("UPDATE transactions SET card_settlement_id = :s WHERE id IN (:p, :o)"),
                {"s": ids["settlement"], "p": ids["purchase"], "o": ids["posted"]},
            )
    engine.dispose()

    upgrade(db_path)

    engine = create_engine(f"sqlite:///{db_path}")
    with engine.connect() as connection:
        remaining = {
            row_id: source
            for row_id, source in connection.execute(
                text("SELECT id, categorization_source FROM transactions")
            )
        }
        opening, cached = connection.execute(
            text("SELECT opening_balance_minor, cached_balance_minor FROM accounts WHERE id = :id"),
            {"id": card_id},
        ).one()
        review = connection.execute(
            text("SELECT category_id, needs_review FROM transactions WHERE id = :id"),
            {"id": ids["settlement"]},
        ).one()
    columns = {column["name"] for column in inspect(engine).get_columns("transactions")}
    engine.dispose()

    # The posted credit is gone; the purchase it offset stays.
    assert set(remaining) == {ids["settlement"], ids["purchase"]}
    # Its amount moved into the opening balance, so the card still reads what it read.
    assert (opening, cached) == (45_210, 0)
    assert remaining[ids["settlement"]] == "uncategorized"
    assert review == (None, 1)
    assert "card_settlement_id" not in columns
