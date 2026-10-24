"""Tests for how a categorisation run treats deferred-card settlements.

The model is only offered the settlement category when the user tracks a card account, never
assigns it outright, and never for a row it cannot be. The stub runtime stands in throughout.
"""

import asyncio
from datetime import date
from uuid import uuid4

from sqlalchemy import select

from app.core.db import SessionFactory
from app.features.accounts.models import Account
from app.features.categories.models import Category
from app.features.categorization.models import CategorizationRun
from app.features.categorization.repository import CategorizationRunRepository, new_run
from app.features.categorization.runner import execute_run
from app.features.imports.card_settlement import CARD_SETTLEMENT_CATEGORY_KEY
from app.features.imports.repository import ImportRepository
from app.features.imports.settlements import CardSettlementService
from app.features.transactions.models import Transaction
from tests.features.categorization.conftest import (
    GROCERIES_ID,
    Ledger,
    StubRuntime,
    assign_all,
    read_transaction,
    seed_ledger,
)

SETTLEMENT_ID = "cat-card-settlement"


def _seed_settlement_category(session_factory: SessionFactory) -> None:
    db = session_factory()
    try:
        if db.get(Category, SETTLEMENT_ID) is None:
            db.add(
                Category(
                    id=SETTLEMENT_ID,
                    name=CARD_SETTLEMENT_CATEGORY_KEY,
                    kind="transfer",
                    icon="credit_card",
                    color="#64748B",
                    is_system=True,
                )
            )
            db.commit()
    finally:
        db.close()


def _add_card(
    session_factory: SessionFactory, ledger: Ledger, rows: list[tuple[date, int]]
) -> tuple[str, list[str]]:
    """A deferred-card account for the ledger's user, holding ``rows`` (date, amount)."""
    db = session_factory()
    try:
        card_id = str(uuid4())
        db.add(
            Account(
                id=card_id,
                user_id=ledger.user_id,
                name="Carte",
                type="deferred_card",
                institution="BNP",
                currency="EUR",
                opening_balance_minor=0,
                cached_balance_minor=sum(amount for _, amount in rows),
            )
        )
        row_ids = []
        for booked, amount in rows:
            row = Transaction(
                account_id=card_id,
                import_batch_id=ledger.batch_id,
                booked_date=booked,
                amount_minor=amount,
                currency="EUR",
                description_raw="CB ACHAT",
                description_clean="CB ACHAT",
                category_id=None,
                categorization_source="uncategorized",
                needs_review=True,
                dedup_hash=str(uuid4()),
            )
            db.add(row)
            db.flush()
            row_ids.append(row.id)
        db.commit()
        return card_id, row_ids
    finally:
        db.close()


def _set_row(session_factory: SessionFactory, row_id: str, **values: object) -> None:
    db = session_factory()
    try:
        row = db.get(Transaction, row_id)
        assert row is not None
        for name, value in values.items():
            setattr(row, name, value)
        db.commit()
    finally:
        db.close()


def _run(session_factory: SessionFactory, ledger: Ledger, runtime: StubRuntime, ids: list[str]):
    db = session_factory()
    try:
        started = CategorizationRunRepository(db).insert_unless_in_flight(
            new_run(
                ledger.user_id,
                trigger="manual",
                account_id=None,
                import_batch_id=None,
                model_tag="stub-model",
                total_count=len(ids),
            )
        )
    finally:
        db.close()
    asyncio.run(
        execute_run(
            started.id,
            ledger.user_id,
            ids,
            session_factory=session_factory,
            client_factory=runtime.factory,
        )
    )
    db = session_factory()
    try:
        stored = db.get(CategorizationRun, started.id)
        assert stored is not None
        db.expunge_all()
        return stored
    finally:
        db.close()


def _offered(runtime: StubRuntime) -> str:
    """Everything the model was shown, for checking which category ids it could pick."""
    return "".join(str(message) for call in runtime.calls for message in call)


def test_without_a_card_account_the_model_is_not_offered_the_settlement(
    session_factory: SessionFactory,
) -> None:
    _seed_settlement_category(session_factory)
    ledger = seed_ledger(session_factory, [("FACTURE CARTE DU 310126", "uncategorized", True)])
    runtime = StubRuntime()
    # Even a model that tries is held back: the id it names was never offered.
    runtime.default = assign_all(1, category_id=SETTLEMENT_ID)

    stored = _run(session_factory, ledger, runtime, ledger.transaction_ids)

    assert SETTLEMENT_ID not in _offered(runtime)
    assert GROCERIES_ID in _offered(runtime)
    row = read_transaction(session_factory, ledger.transaction_ids[0])
    assert row.category_id is None
    assert stored.assigned_count == 0


def test_a_settlement_the_model_names_is_proposed_not_assigned(
    session_factory: SessionFactory,
) -> None:
    _seed_settlement_category(session_factory)
    ledger = seed_ledger(session_factory, [("PRLV MENSUEL CARTE", "uncategorized", True)])
    _add_card(session_factory, ledger, [])
    runtime = StubRuntime()
    runtime.default = assign_all(1, category_id=SETTLEMENT_ID, confidence=0.99)

    stored = _run(session_factory, ledger, runtime, ledger.transaction_ids)

    assert SETTLEMENT_ID in _offered(runtime)
    row = read_transaction(session_factory, ledger.transaction_ids[0])
    assert row.category_id == SETTLEMENT_ID
    assert row.categorization_source == "model"
    assert row.categorization_confidence == 0.99
    # However confident, the user has the last word on a settlement.
    assert row.needs_review is True
    assert stored.assigned_count == 0
    assert stored.deferred_count == 1


def test_the_model_cannot_file_a_card_row_as_a_settlement(
    session_factory: SessionFactory,
) -> None:
    _seed_settlement_category(session_factory)
    ledger = seed_ledger(session_factory, [])
    _, card_rows = _add_card(session_factory, ledger, [(date(2026, 7, 3), -4_235)])
    runtime = StubRuntime()
    runtime.default = assign_all(1, category_id=SETTLEMENT_ID)

    _run(session_factory, ledger, runtime, card_rows)

    row = read_transaction(session_factory, card_rows[0])
    assert row.category_id is None
    assert row.categorization_source == "uncategorized"


def test_a_settlement_the_model_found_is_linked_at_the_end_of_the_run(
    session_factory: SessionFactory,
) -> None:
    # The ledger's single debit (−42.35 on 1 July) pays the card's June cycle exactly.
    _seed_settlement_category(session_factory)
    ledger = seed_ledger(session_factory, [("PRLV MENSUEL CARTE", "uncategorized", True)])
    card_id, _ = _add_card(
        session_factory, ledger, [(date(2026, 6, 10), -3_000), (date(2026, 6, 20), -1_235)]
    )
    runtime = StubRuntime()
    runtime.default = assign_all(1, category_id=SETTLEMENT_ID)

    _run(session_factory, ledger, runtime, ledger.transaction_ids)

    db = session_factory()
    try:
        credits = db.scalars(
            select(Transaction).where(
                Transaction.account_id == card_id, Transaction.amount_minor > 0
            )
        ).all()
        assert [(row.amount_minor, row.card_settlement_id) for row in credits] == [
            (4_235, ledger.transaction_ids[0])
        ]
        card = db.get(Account, card_id)
        assert card is not None
        assert card.cached_balance_minor == 0
    finally:
        db.close()


def test_a_settlement_the_model_filed_elsewhere_is_reconsidered_once_a_card_exists(
    session_factory: SessionFactory,
) -> None:
    # Filed as groceries by the model before the card account existed, and never confirmed.
    _seed_settlement_category(session_factory)
    ledger = seed_ledger(session_factory, [("FACTURE CARTE DU 300626", "uncategorized", True)])
    settlement_id = ledger.transaction_ids[0]
    _set_row(
        session_factory,
        settlement_id,
        category_id=GROCERIES_ID,
        categorization_source="model",
        categorization_confidence=0.9,
        needs_review=False,
    )
    _add_card(session_factory, ledger, [(date(2026, 6, 10), -4_235)])

    db = session_factory()
    try:
        settlements = CardSettlementService(ImportRepository(db), db)
        settlements.link_pending(
            ledger.user_id, settlements.tracked_cards(ledger.user_id), SETTLEMENT_ID
        )
        db.commit()
    finally:
        db.close()

    row = read_transaction(session_factory, settlement_id)
    assert row.category_id == SETTLEMENT_ID
    assert row.categorization_source == "detected"
    assert row.needs_review is True


def test_a_settlement_the_user_filed_elsewhere_stays_theirs(
    session_factory: SessionFactory,
) -> None:
    _seed_settlement_category(session_factory)
    ledger = seed_ledger(session_factory, [("FACTURE CARTE DU 300626", "uncategorized", True)])
    settlement_id = ledger.transaction_ids[0]
    _set_row(
        session_factory,
        settlement_id,
        category_id=GROCERIES_ID,
        categorization_source="user",
        needs_review=False,
    )
    _add_card(session_factory, ledger, [(date(2026, 6, 10), -4_235)])

    db = session_factory()
    try:
        settlements = CardSettlementService(ImportRepository(db), db)
        settlements.link_pending(
            ledger.user_id, settlements.tracked_cards(ledger.user_id), SETTLEMENT_ID
        )
        db.commit()
    finally:
        db.close()

    assert read_transaction(session_factory, settlement_id).category_id == GROCERIES_ID
