"""Tests for the run executor: per-batch commit, cancellation, scoping, status, reconciliation.

The inference runtime is a stub throughout — these tests are about what the executor does with
an answer, never about getting one.
"""

import asyncio
from collections.abc import Coroutine
from typing import Any

from app.core.db import SessionFactory
from app.features.categorization.models import CategorizationRun
from app.features.categorization.repository import CategorizationRunRepository, new_run
from app.features.categorization.runner import (
    ORPHANED_RUN_MESSAGE,
    execute_run,
    reconcile_orphaned_runs,
)
from app.features.categorization.service import BATCH_SIZE
from app.features.inference.client import InferenceUnavailable
from app.features.transactions.models import Transaction
from tests.features.categorization.conftest import (
    GROCERIES_ID,
    SALARY_ID,
    Ledger,
    StubRuntime,
    assign_all,
    read_transaction,
    seed_ledger,
)

#: The `(categorization_source, needs_review)` pair of a row nothing has categorised yet.
UNCATEGORIZED = ("uncategorized", True)


def run[T](coro: Coroutine[Any, Any, T]) -> T:
    """Drive one coroutine to completion (avoids depending on an async pytest plugin)."""
    return asyncio.run(coro)


def _pending_rows(count: int) -> list[tuple[str, str, bool]]:
    return [(f"CARREFOUR {index}", *UNCATEGORIZED) for index in range(count)]


def _start_run(session_factory: SessionFactory, ledger: Ledger, total: int) -> CategorizationRun:
    """Insert a `pending` run the executor can pick up, as the service would have."""
    db = session_factory()
    try:
        return CategorizationRunRepository(db).insert_unless_in_flight(
            new_run(
                ledger.user_id,
                trigger="manual",
                account_id=None,
                import_batch_id=None,
                model_tag="stub-model",
                total_count=total,
            )
        )
    finally:
        db.close()


def _read_run(session_factory: SessionFactory, run_id: str) -> CategorizationRun:
    """Re-read a run on a fresh session, so no cached row can mask a missing write."""
    db = session_factory()
    try:
        stored = db.get(CategorizationRun, run_id)
        assert stored is not None
        db.expunge_all()
        return stored
    finally:
        db.close()


def _cancel(session_factory: SessionFactory, run_id: str) -> None:
    """Cancel a run from outside the executor, as the cancel endpoint's session would."""
    db = session_factory()
    try:
        stored = db.get(CategorizationRun, run_id)
        assert stored is not None
        stored.status = "cancelled"
        db.commit()
    finally:
        db.close()


def _sources(session_factory: SessionFactory, ledger: Ledger) -> list[str]:
    return [
        read_transaction(session_factory, row_id).categorization_source
        for row_id in ledger.transaction_ids
    ]


def _execute(
    session_factory: SessionFactory,
    ledger: Ledger,
    run_id: str,
    runtime: StubRuntime,
    transaction_ids: list[str] | None = None,
) -> None:
    run(
        execute_run(
            run_id,
            ledger.user_id,
            ledger.transaction_ids if transaction_ids is None else transaction_ids,
            session_factory=session_factory,
            client_factory=runtime.factory,
        )
    )


def test_confident_rows_are_assigned_and_the_run_succeeds(session_factory: SessionFactory) -> None:
    ledger = seed_ledger(session_factory, _pending_rows(3))
    started = _start_run(session_factory, ledger, 3)
    runtime = StubRuntime()
    runtime.default = assign_all(3)

    _execute(session_factory, ledger, started.id, runtime)

    stored = _read_run(session_factory, started.id)
    assert stored.status == "success"
    assert stored.processed_count == 3
    assert stored.assigned_count == 3
    assert stored.deferred_count == 0
    assert stored.failed_count == 0
    assert stored.started_at is not None
    assert stored.finished_at is not None

    row = read_transaction(session_factory, ledger.transaction_ids[0])
    assert row.category_id == GROCERIES_ID
    assert row.categorization_source == "model"
    assert row.categorization_confidence == 0.95
    assert row.needs_review is False


def test_each_batch_is_committed_before_the_next_one_is_asked_for(
    session_factory: SessionFactory,
) -> None:
    """Observe the database from inside the second batch: the first must already be durable.

    This is the durability property stated directly — not "the counts look right
    at the end", but "the work was on disk before the next batch was attempted", which is the
    only version of it a crash can benefit from.
    """
    row_count = BATCH_SIZE * 2
    ledger = seed_ledger(session_factory, _pending_rows(row_count))
    started = _start_run(session_factory, ledger, row_count)

    observed: dict[str, int] = {}
    runtime = StubRuntime()
    runtime.default = assign_all(BATCH_SIZE)

    def snapshot_before_second_batch(call: int) -> None:
        if call != 2:
            return
        observed["processed"] = _read_run(session_factory, started.id).processed_count
        observed["applied"] = _sources(session_factory, ledger).count("model")

    runtime.on_call.append(snapshot_before_second_batch)

    _execute(session_factory, ledger, started.id, runtime)

    assert observed == {"processed": BATCH_SIZE, "applied": BATCH_SIZE}
    assert _read_run(session_factory, started.id).processed_count == row_count


def test_a_crash_mid_run_keeps_completed_batches_and_an_accurate_count(
    session_factory: SessionFactory,
) -> None:
    row_count = BATCH_SIZE * 2
    ledger = seed_ledger(session_factory, _pending_rows(row_count))
    started = _start_run(session_factory, ledger, row_count)

    runtime = StubRuntime()
    runtime.default = assign_all(BATCH_SIZE)
    # Something no `except InferenceError` will catch — the executor's last-resort path.
    runtime.on_call.append(_raise_on_second_call)

    _execute(session_factory, ledger, started.id, runtime)

    stored = _read_run(session_factory, started.id)
    assert stored.status == "failed"
    assert stored.error_message is not None
    # The first batch survived, and `processed_count` describes exactly those rows.
    assert stored.processed_count == BATCH_SIZE
    assert stored.assigned_count == BATCH_SIZE
    sources = _sources(session_factory, ledger)
    assert sources.count("model") == BATCH_SIZE
    assert sources.count("uncategorized") == BATCH_SIZE


def _raise_on_second_call(call: int) -> None:
    if call == 2:
        raise RuntimeError("the executor died")


def test_reconciliation_fails_a_run_left_in_flight_by_a_dead_process(
    session_factory: SessionFactory,
) -> None:
    ledger = seed_ledger(session_factory, _pending_rows(2))
    started = _start_run(session_factory, ledger, 2)
    db = session_factory()
    try:
        stored = db.get(CategorizationRun, started.id)
        assert stored is not None
        stored.status = "running"
        stored.processed_count = 1
        stored.assigned_count = 1
        db.commit()
    finally:
        db.close()

    assert reconcile_orphaned_runs(session_factory) == 1

    reconciled = _read_run(session_factory, started.id)
    assert reconciled.status == "failed"
    assert reconciled.error_message == ORPHANED_RUN_MESSAGE
    assert reconciled.finished_at is not None
    # The batch it did finish is not undone by reconciling the run.
    assert reconciled.processed_count == 1
    assert reconciled.assigned_count == 1


def test_reconciliation_leaves_finished_runs_alone(session_factory: SessionFactory) -> None:
    ledger = seed_ledger(session_factory, _pending_rows(1))
    started = _start_run(session_factory, ledger, 1)
    runtime = StubRuntime()
    runtime.default = assign_all(1)
    _execute(session_factory, ledger, started.id, runtime)

    assert reconcile_orphaned_runs(session_factory) == 0
    assert _read_run(session_factory, started.id).status == "success"


def test_reconciliation_releases_the_one_run_at_a_time_lock(
    session_factory: SessionFactory,
) -> None:
    """An orphan left in flight would block every future run; reconciling must free it."""
    ledger = seed_ledger(session_factory, _pending_rows(1))
    orphan = _start_run(session_factory, ledger, 1)

    reconcile_orphaned_runs(session_factory)

    assert _start_run(session_factory, ledger, 1).id != orphan.id


def test_cancellation_stops_between_batches_and_keeps_completed_batches(
    session_factory: SessionFactory,
) -> None:
    row_count = BATCH_SIZE * 3
    ledger = seed_ledger(session_factory, _pending_rows(row_count))
    started = _start_run(session_factory, ledger, row_count)

    runtime = StubRuntime()
    runtime.default = assign_all(BATCH_SIZE)
    # Cancelled while the first batch is in flight, as a user clicking "stop" would.
    runtime.on_call.append(lambda call: _cancel(session_factory, started.id) if call == 1 else None)

    _execute(session_factory, ledger, started.id, runtime)

    stored = _read_run(session_factory, started.id)
    assert stored.status == "cancelled"
    assert stored.finished_at is not None
    # The batch already in flight finished and was applied; the other two never ran.
    assert stored.processed_count == BATCH_SIZE
    assert len(runtime.calls) == 1
    assert _sources(session_factory, ledger).count("model") == BATCH_SIZE


def test_a_run_cancelled_before_it_starts_never_reaches_the_runtime(
    session_factory: SessionFactory,
) -> None:
    ledger = seed_ledger(session_factory, _pending_rows(2))
    started = _start_run(session_factory, ledger, 2)
    _cancel(session_factory, started.id)
    runtime = StubRuntime()

    _execute(session_factory, ledger, started.id, runtime)

    assert runtime.calls == []
    assert _read_run(session_factory, started.id).status == "cancelled"


def test_user_and_rule_rows_are_never_selected_or_modified(
    session_factory: SessionFactory,
) -> None:
    ledger = seed_ledger(
        session_factory,
        [
            ("CARREFOUR", *UNCATEGORIZED),
            ("SALAIRE", "user", False),
            ("NETFLIX", "rule", False),
            ("EDF", "model", False),
        ],
    )
    db = session_factory()
    try:
        candidates = CategorizationRunRepository(db).select_candidate_ids(ledger.user_id, "pending")
    finally:
        db.close()

    assert candidates == [ledger.transaction_ids[0]]

    started = _start_run(session_factory, ledger, 1)
    runtime = StubRuntime()
    runtime.default = assign_all(1)
    _execute(session_factory, ledger, started.id, runtime, transaction_ids=candidates)

    for index, expected_source in ((1, "user"), (2, "rule")):
        untouched = read_transaction(session_factory, ledger.transaction_ids[index])
        assert untouched.categorization_source == expected_source
        assert untouched.category_id == SALARY_ID
        assert untouched.needs_review is False


def test_scope_all_adds_model_rows_but_still_never_user_or_rule(
    session_factory: SessionFactory,
) -> None:
    ledger = seed_ledger(
        session_factory,
        [
            ("CARREFOUR", *UNCATEGORIZED),
            ("SALAIRE", "user", False),
            ("NETFLIX", "rule", False),
            ("EDF", "model", False),
        ],
    )
    db = session_factory()
    try:
        candidates = CategorizationRunRepository(db).select_candidate_ids(ledger.user_id, "all")
    finally:
        db.close()

    assert set(candidates) == {ledger.transaction_ids[0], ledger.transaction_ids[3]}


def test_selection_is_user_scoped_and_narrows_to_one_account(
    session_factory: SessionFactory,
) -> None:
    mine = seed_ledger(session_factory, _pending_rows(2))
    second_account = seed_ledger(session_factory, _pending_rows(1), user_id=mine.user_id)
    seed_ledger(session_factory, _pending_rows(3))  # another user entirely

    db = session_factory()
    try:
        repository = CategorizationRunRepository(db)
        everything = repository.select_candidate_ids(mine.user_id, "pending")
        one_account = repository.select_candidate_ids(
            mine.user_id, "pending", second_account.account_id
        )
    finally:
        db.close()

    assert set(everything) == set(mine.transaction_ids) | set(second_account.transaction_ids)
    assert one_account == second_account.transaction_ids


def test_the_executor_will_not_touch_another_users_rows(session_factory: SessionFactory) -> None:
    mine = seed_ledger(session_factory, _pending_rows(1))
    theirs = seed_ledger(session_factory, _pending_rows(1))
    started = _start_run(session_factory, mine, 2)
    runtime = StubRuntime()
    runtime.default = assign_all(2)

    _execute(
        session_factory,
        mine,
        started.id,
        runtime,
        transaction_ids=mine.transaction_ids + theirs.transaction_ids,
    )

    assert _sources(session_factory, theirs) == ["uncategorized"]
    assert _read_run(session_factory, started.id).processed_count == 1


def test_a_runtime_down_for_the_whole_run_ends_failed(session_factory: SessionFactory) -> None:
    ledger = seed_ledger(session_factory, _pending_rows(2))
    started = _start_run(session_factory, ledger, 2)
    runtime = StubRuntime()
    runtime.default = InferenceUnavailable("nothing is listening")

    _execute(session_factory, ledger, started.id, runtime)

    stored = _read_run(session_factory, started.id)
    assert stored.status == "failed"
    assert stored.error_message is not None
    assert stored.processed_count == 2
    assert stored.failed_count == 2
    assert stored.assigned_count == 0
    # Nothing was written to the rows; they stay where they were, in the review queue.
    row = read_transaction(session_factory, ledger.transaction_ids[0])
    assert row.categorization_source == "uncategorized"
    assert row.needs_review is True


def test_some_rows_failing_ends_partial(session_factory: SessionFactory) -> None:
    row_count = BATCH_SIZE + 2
    ledger = seed_ledger(session_factory, _pending_rows(row_count))
    started = _start_run(session_factory, ledger, row_count)
    runtime = StubRuntime()
    runtime.replies = [assign_all(BATCH_SIZE), InferenceUnavailable("it went away")]

    _execute(session_factory, ledger, started.id, runtime)

    stored = _read_run(session_factory, started.id)
    assert stored.status == "partial"
    assert stored.processed_count == row_count
    assert stored.assigned_count == BATCH_SIZE
    assert stored.failed_count == 2
    # `partial`, not `failed`: the run placed rows, and saying otherwise would disown them.
    assert stored.error_message is None


def test_low_confidence_rows_are_deferred_and_the_run_still_succeeds(
    session_factory: SessionFactory,
) -> None:
    ledger = seed_ledger(session_factory, _pending_rows(2))
    started = _start_run(session_factory, ledger, 2)
    runtime = StubRuntime()
    runtime.default = assign_all(2, confidence=0.42)

    _execute(session_factory, ledger, started.id, runtime)

    stored = _read_run(session_factory, started.id)
    assert stored.status == "success"
    assert stored.assigned_count == 0
    assert stored.deferred_count == 2

    row = read_transaction(session_factory, ledger.transaction_ids[0])
    assert row.category_id is None
    assert row.categorization_source == "uncategorized"
    assert row.needs_review is True


def test_an_unparseable_reply_defers_rather_than_aborting_the_run(
    session_factory: SessionFactory,
) -> None:
    ledger = seed_ledger(session_factory, _pending_rows(2))
    started = _start_run(session_factory, ledger, 2)
    runtime = StubRuntime()
    runtime.default = "I'm afraid I can't do that."

    _execute(session_factory, ledger, started.id, runtime)

    stored = _read_run(session_factory, started.id)
    assert stored.status == "success"
    assert stored.deferred_count == 2
    assert stored.failed_count == 0


def test_a_run_with_no_rows_finishes_immediately_without_calling_the_runtime(
    session_factory: SessionFactory,
) -> None:
    ledger = seed_ledger(session_factory, [])
    started = _start_run(session_factory, ledger, 0)
    runtime = StubRuntime()

    _execute(session_factory, ledger, started.id, runtime)

    stored = _read_run(session_factory, started.id)
    assert stored.status == "success"
    assert stored.total_count == 0
    assert runtime.calls == []


def test_a_second_run_is_refused_while_one_is_in_flight(session_factory: SessionFactory) -> None:
    ledger = seed_ledger(session_factory, _pending_rows(2))
    first = _start_run(session_factory, ledger, 2)

    second = _start_run(session_factory, ledger, 2)

    assert second.id == first.id


def test_a_second_run_is_allowed_once_the_first_has_finished(
    session_factory: SessionFactory,
) -> None:
    ledger = seed_ledger(session_factory, _pending_rows(1))
    first = _start_run(session_factory, ledger, 1)
    runtime = StubRuntime()
    runtime.default = assign_all(1)
    _execute(session_factory, ledger, first.id, runtime)

    second = _start_run(session_factory, ledger, 1)

    assert second.id != first.id


def test_one_users_in_flight_run_does_not_block_another_users(
    session_factory: SessionFactory,
) -> None:
    mine = seed_ledger(session_factory, _pending_rows(1))
    theirs = seed_ledger(session_factory, _pending_rows(1))

    first = _start_run(session_factory, mine, 1)
    second = _start_run(session_factory, theirs, 1)

    assert second.id != first.id


def test_the_run_records_the_model_it_used(session_factory: SessionFactory) -> None:
    ledger = seed_ledger(session_factory, _pending_rows(1))

    started = _start_run(session_factory, ledger, 1)

    assert started.model_tag == "stub-model"


def test_no_model_configured_defers_every_row_without_calling_the_runtime(
    session_factory: SessionFactory,
) -> None:
    ledger = seed_ledger(session_factory, _pending_rows(2), model_tag=None)
    started = _start_run(session_factory, ledger, 2)
    runtime = StubRuntime()

    _execute(session_factory, ledger, started.id, runtime)

    stored = _read_run(session_factory, started.id)
    assert runtime.calls == []
    assert stored.status == "success"
    assert stored.deferred_count == 2
    assert _sources(session_factory, ledger) == ["uncategorized", "uncategorized"]


def test_money_stays_untouched_by_a_run(session_factory: SessionFactory) -> None:
    """A run writes categories, never amounts."""
    ledger = seed_ledger(session_factory, _pending_rows(1))
    started = _start_run(session_factory, ledger, 1)
    runtime = StubRuntime()
    runtime.default = assign_all(1)

    _execute(session_factory, ledger, started.id, runtime)

    row = read_transaction(session_factory, ledger.transaction_ids[0])
    assert isinstance(row.amount_minor, int)
    assert row.amount_minor == -4235
    assert row.currency == "EUR"


def test_transactions_are_reloaded_in_the_order_they_were_selected(
    session_factory: SessionFactory,
) -> None:
    """The reply correlates by batch index, so a reordered reload would mis-assign rows."""
    ledger = seed_ledger(session_factory, _pending_rows(4))
    db = session_factory()
    try:
        reversed_ids = list(reversed(ledger.transaction_ids))
        rows = CategorizationRunRepository(db).list_transactions(ledger.user_id, reversed_ids)
        assert [row.id for row in rows] == reversed_ids
        assert all(isinstance(row, Transaction) for row in rows)
    finally:
        db.close()
