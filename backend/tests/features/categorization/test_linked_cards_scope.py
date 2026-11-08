"""A run scoped to an account with `include_linked_cards` reads that account's review queue.

The review queue for an account lists its linked cards' rows too, and a run started from that
queue must take exactly those rows: the same linked-card definition on both sides.
"""

from fastapi.testclient import TestClient

from app.core.db import SessionFactory
from app.features.accounts.models import Account
from app.features.categorization.repository import CategorizationRunRepository
from tests.api import register as _register
from tests.features.categorization.conftest import (
    Ledger,
    RunLauncherSpy,
    StubRuntime,
    seed_ledger,
)

RUNS = "/api/v1/categorization/runs"
TRANSACTIONS = "/api/v1/transactions"


def _pending(count: int, prefix: str = "CAFE DU PORT") -> list[tuple[str, str, bool]]:
    return [(f"{prefix} {index}", "uncategorized", True) for index in range(count)]


def _make_card(
    session_factory: SessionFactory,
    ledger: Ledger,
    settled_on: str | None,
    *,
    archived: bool = False,
) -> None:
    """Turn ``ledger``'s account into a deferred card settled on ``settled_on``."""
    db = session_factory()
    try:
        card = db.get(Account, ledger.account_id)
        assert card is not None
        card.type = "deferred_card"
        card.settlement_account_id = settled_on
        card.archived = archived
        db.commit()
    finally:
        db.close()


def _candidates(
    session_factory: SessionFactory, user_id: str, account_id: str, **kwargs: bool
) -> list[str]:
    db = session_factory()
    try:
        return CategorizationRunRepository(db).select_candidate_ids(
            user_id, "pending", account_id, **kwargs
        )
    finally:
        db.close()


def test_linked_cards_widen_the_run_to_live_cards_of_the_same_user(
    session_factory: SessionFactory,
) -> None:
    checking = seed_ledger(session_factory, _pending(2))
    card = seed_ledger(session_factory, _pending(2, "CARTE X4821"), user_id=checking.user_id)
    _make_card(session_factory, card, checking.account_id)
    archived = seed_ledger(session_factory, _pending(1, "OLD CARD"), user_id=checking.user_id)
    _make_card(session_factory, archived, checking.account_id, archived=True)
    unlinked = seed_ledger(session_factory, _pending(1, "OTHER"), user_id=checking.user_id)
    _make_card(session_factory, unlinked, None)
    # Another user's card pointing at this account must never be read through it.
    stranger = seed_ledger(session_factory, _pending(1, "STRANGER"))
    _make_card(session_factory, stranger, checking.account_id)

    widened = _candidates(
        session_factory, checking.user_id, checking.account_id, include_linked_cards=True
    )

    assert set(widened) == set(checking.transaction_ids) | set(card.transaction_ids)


def test_without_the_option_the_run_stays_on_the_account_alone(
    session_factory: SessionFactory,
) -> None:
    checking = seed_ledger(session_factory, _pending(2))
    card = seed_ledger(session_factory, _pending(2, "CARTE X4821"), user_id=checking.user_id)
    _make_card(session_factory, card, checking.account_id)

    default = _candidates(session_factory, checking.user_id, checking.account_id)

    assert default == checking.transaction_ids


def test_the_runs_input_is_exactly_the_accounts_review_queue(
    client: TestClient,
    api_session_factory: SessionFactory,
    launcher: RunLauncherSpy,
    runtime: StubRuntime,
) -> None:
    headers = _register(client)
    user_id = client.get("/api/v1/auth/me", headers=headers).json()["user"]["id"]
    checking = seed_ledger(
        api_session_factory,
        [*_pending(2), ("SALAIRE", "user", False), ("NETFLIX", "rule", False)],
        user_id=user_id,
    )
    card = seed_ledger(
        api_session_factory,
        [*_pending(2, "CARTE X4821"), ("BOULANGERIE", "user", False)],
        user_id=user_id,
    )
    _make_card(api_session_factory, card, checking.account_id)
    archived = seed_ledger(api_session_factory, _pending(1, "OLD CARD"), user_id=user_id)
    _make_card(api_session_factory, archived, checking.account_id, archived=True)

    queue = client.get(
        TRANSACTIONS,
        params={
            "account_id": checking.account_id,
            "needs_review": "true",
            "include_linked_cards": "true",
        },
        headers=headers,
    ).json()
    run = client.post(
        RUNS,
        json={
            "scope": "pending",
            "account_id": checking.account_id,
            "include_linked_cards": True,
        },
        headers=headers,
    )

    assert run.status_code == 202
    queue_ids = {item["id"] for item in queue["items"]}
    run_input = set(
        _candidates(api_session_factory, user_id, checking.account_id, include_linked_cards=True)
    )
    assert queue_ids == run_input
    assert queue_ids == set(checking.transaction_ids[:2]) | set(card.transaction_ids[:2])
    assert run.json()["total_count"] == queue["total"] == 4
    launcher.discard()


def test_a_run_request_without_the_option_keeps_its_account_only_count(
    client: TestClient,
    api_session_factory: SessionFactory,
    launcher: RunLauncherSpy,
    runtime: StubRuntime,
) -> None:
    headers = _register(client)
    user_id = client.get("/api/v1/auth/me", headers=headers).json()["user"]["id"]
    checking = seed_ledger(api_session_factory, _pending(2), user_id=user_id)
    card = seed_ledger(api_session_factory, _pending(3, "CARTE X4821"), user_id=user_id)
    _make_card(api_session_factory, card, checking.account_id)

    run = client.post(
        RUNS, json={"scope": "pending", "account_id": checking.account_id}, headers=headers
    )

    assert run.status_code == 202
    assert run.json()["total_count"] == 2
    launcher.discard()
