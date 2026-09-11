"""Orchestration around the stage-2 decision layer: runs, progress, and cancellation.

`service.py` decides what one batch of rows should become; nothing there touches a database or
knows a run exists. This module is the other half: it picks the rows, opens its own session,
walks the batches, commits progress as it goes, and settles on a terminal status. The split is
why every decision rule is testable without a database and every orchestration rule here is
testable with a stub client.

The executor deliberately runs as a plain asyncio task rather than through a queue or broker:
the sidecar is one process serving one user (`PROJECT.md` §3), so a broker would add an
operational dependency to buy concurrency nobody has.
"""

import asyncio
import logging
from collections.abc import Callable, Coroutine
from datetime import UTC, datetime
from typing import Any

from sqlalchemy.orm import Session

from app.core.db import SessionFactory
from app.core.errors import ConflictError, NotFoundError
from app.features.accounts.service import AccountService
from app.features.auth.models import User
from app.features.categories.repository import CategoryRepository
from app.features.categorization.models import CategorizationRun
from app.features.categorization.prompt import leaf_categories
from app.features.categorization.repository import CategorizationRunRepository, new_run
from app.features.categorization.schemas import RunCreate, RunTrigger
from app.features.categorization.service import BATCH_SIZE, categorize_batch
from app.features.inference.client import InferenceClient, client_from_settings
from app.features.settings.models import UserSettings
from app.features.settings.repository import SettingsRepository
from app.features.settings.service import SettingsService

logger = logging.getLogger(__name__)

#: Builds the runtime client for a user's settings. Injected so no test reaches a runtime.
type ClientFactory = Callable[[UserSettings], InferenceClient]

#: Hands a coroutine off to run detached from the request that created it. Injected so tests
#: can drive the executor deterministically instead of racing the event loop.
type RunLauncher = Callable[[Coroutine[Any, Any, None]], None]

RUNTIME_UNREACHABLE_MESSAGE = "The inference runtime did not answer for any row of this run."
ORPHANED_RUN_MESSAGE = "The run was interrupted when the application stopped."

# Tasks are held here for as long as they run: asyncio keeps only a weak reference to a task,
# so one that nothing else holds can be garbage-collected mid-run.
_background_tasks: set[asyncio.Task[None]] = set()


class RunNotFoundError(NotFoundError):
    """Raised when a run doesn't exist or doesn't belong to the caller."""

    code = "CATEGORIZATION_RUN_NOT_FOUND"


class RunNotCancellableError(ConflictError):
    """Raised when cancelling a run that has already reached a terminal status."""

    code = "CATEGORIZATION_RUN_NOT_CANCELLABLE"


def launch_in_background(coro: Coroutine[Any, Any, None]) -> None:
    """Schedule ``coro`` on the running loop and return at once.

    Requires a running event loop, which is what an `async def` route body gives it — the
    202 goes out on the current task while the run continues on the new one.
    """
    task = asyncio.create_task(coro)
    _background_tasks.add(task)
    task.add_done_callback(_background_tasks.discard)


def get_run_launcher() -> RunLauncher:
    """The launcher dependency; overridden in tests to make execution deterministic."""
    return launch_in_background


def get_client_factory() -> ClientFactory:
    """The runtime-client factory dependency; overridden in tests so nothing leaves."""
    return client_from_settings


def reconcile_orphaned_runs(session_factory: SessionFactory) -> int:
    """Fail every run still in flight at startup; return how many there were.

    A run's executor is an in-process task, so a run that was `pending` or `running` when the
    process stopped has nobody left to finish it (`PROJECT.md` §7). The rows its completed
    batches already committed stay categorised — that is the point of committing per batch.
    """
    db = session_factory()
    try:
        count = CategorizationRunRepository(db).fail_orphaned(ORPHANED_RUN_MESSAGE)
    finally:
        db.close()
    if count:
        logger.info("Marked %d interrupted categorization run(s) as failed.", count)
    return count


class CategorizationRunService:
    """Starts, lists, reads, and cancels runs. Owns no execution itself."""

    def __init__(
        self,
        repository: CategorizationRunRepository,
        account_service: AccountService,
        settings_service: SettingsService,
        session_factory: SessionFactory,
        launcher: RunLauncher,
        client_factory: ClientFactory,
    ) -> None:
        self._repository = repository
        self._account_service = account_service
        self._settings_service = settings_service
        self._session_factory = session_factory
        self._launcher = launcher
        self._client_factory = client_factory

    def request(
        self,
        user: User,
        data: RunCreate,
        *,
        trigger: RunTrigger = "manual",
        import_batch_id: str | None = None,
    ) -> CategorizationRun:
        """Create a run over the rows ``data`` selects and start it in the background.

        Returns the in-flight run instead of creating a second one when the user already has
        one — the caller cannot tell the two cases apart, and does not need to: either way the
        run it gets back is the one that will process its rows.

        Raises:
            AccountNotFoundError: `data.account_id` doesn't exist or isn't the user's.
        """
        if data.account_id is not None:
            self._account_service.get(user.id, data.account_id)

        settings = self._settings_service.get_or_create(user.id)
        candidate_ids = self._repository.select_candidate_ids(user.id, data.scope, data.account_id)

        candidate = new_run(
            user.id,
            trigger=trigger,
            account_id=data.account_id,
            import_batch_id=import_batch_id,
            model_tag=settings.model_tag,
            total_count=len(candidate_ids),
        )
        run = self._repository.insert_unless_in_flight(candidate)
        if run.id != candidate.id:
            # An in-flight run already owns these rows; hand it back rather than starting a
            # second executor over them. Identity, not status, is what says whose insert won.
            return run

        self._launcher(
            execute_run(
                run.id,
                user.id,
                candidate_ids,
                session_factory=self._session_factory,
                client_factory=self._client_factory,
            )
        )
        return run

    def list_for_user(self, user_id: str, limit: int) -> list[CategorizationRun]:
        """The user's run history, newest first."""
        return self._repository.list_by_user(user_id, limit)

    def get(self, user_id: str, run_id: str) -> CategorizationRun:
        """Fetch a single run the user owns — the progress poll.

        Raises:
            RunNotFoundError: no such run, or it belongs to another user.
        """
        run = self._repository.get_by_id_for_user(run_id, user_id)
        if run is None:
            raise RunNotFoundError("Categorization run not found.")
        return run

    def cancel(self, user_id: str, run_id: str) -> CategorizationRun:
        """Ask an in-flight run to stop; the executor notices between batches.

        Cancelling is a request, not an interruption: the batch in progress finishes and
        commits, and only then does the executor stop. Everything it had already applied
        stays applied.

        Raises:
            RunNotFoundError: no such run, or it belongs to another user.
            RunNotCancellableError: the run has already finished — a 409 rather than a
                silent no-op, because "cancelled" would otherwise report a stop that never
                happened over work that is already done.
        """
        run = self.get(user_id, run_id)
        if run.status not in ("pending", "running"):
            raise RunNotCancellableError(f"This run has already finished ({run.status}).")

        run.status = "cancelled"
        run.finished_at = datetime.now(UTC)
        self._repository.commit()
        return run


class ImportRunEnqueuer:
    """Starts a run over what an import left uncategorised, when the user has AI switched on.

    Lives here rather than in the imports feature so the import service depends on a callable
    it is handed, not on categorisation. Silent by design in every branch: an import must
    finish the same way whether or not a model is configured, reachable, or wanted
    (`PROJECT.md` §7), so nothing this class does can turn into an import error.
    """

    def __init__(
        self,
        settings_service: SettingsService,
        run_service: CategorizationRunService,
    ) -> None:
        self._settings_service = settings_service
        self._run_service = run_service

    def __call__(self, user: User, account_id: str, import_batch_id: str) -> None:
        """Enqueue a run for ``account_id``, or do nothing at all if AI is switched off."""
        settings = self._settings_service.get_or_create(user.id)
        if not settings.ai_enabled:
            return

        try:
            self._run_service.request(
                user,
                RunCreate(account_id=account_id, scope="pending"),
                trigger="import",
                import_batch_id=import_batch_id,
            )
        except Exception:
            # The import has already committed and its response is owed to the user. A run
            # that could not even be created is worth a log line and nothing more.
            logger.exception("Could not enqueue a categorization run after an import.")


async def execute_run(
    run_id: str,
    user_id: str,
    transaction_ids: list[str],
    *,
    session_factory: SessionFactory,
    client_factory: ClientFactory,
) -> None:
    """Run stage 2 over ``transaction_ids``, committing progress after every batch.

    Opens and owns its own session: the request that created the run is long gone by the time
    most of this executes. Never raises — a run reports its own failure in its row, since
    there is no caller left to tell.
    """
    db = session_factory()
    try:
        await _execute(db, run_id, user_id, transaction_ids, client_factory)
    except Exception as exc:  # noqa: BLE001 — the last frame before the task is discarded.
        logger.exception("Categorization run %s failed unexpectedly.", run_id)
        _fail_quietly(session_factory, run_id, str(exc))
    finally:
        db.close()


async def _execute(
    db: Session,
    run_id: str,
    user_id: str,
    transaction_ids: list[str],
    client_factory: ClientFactory,
) -> None:
    """Drive one run from `pending` to a terminal status."""
    repository = CategorizationRunRepository(db)
    run = repository.get_by_id_for_user(run_id, user_id)
    if run is None or run.status != "pending":
        # Cancelled before it started, or already picked up. Either way it is not ours.
        return

    run.status = "running"
    run.started_at = datetime.now(UTC)
    repository.commit()

    settings = SettingsService(SettingsRepository(db)).get_or_create(user_id)
    # Built once for the whole run: the category list is the fixed part of every prompt.
    categories = leaf_categories(
        CategoryRepository(db).list_for_user(user_id), _locale(db, user_id)
    )
    client = client_factory(settings)

    for start in range(0, len(transaction_ids), BATCH_SIZE):
        if repository.read_status(run_id) == "cancelled":
            # Set by `cancel` on another session; visible because the previous batch committed.
            run.finished_at = datetime.now(UTC)
            repository.commit()
            return

        rows = repository.list_transactions(user_id, transaction_ids[start : start + BATCH_SIZE])
        if not rows:
            continue

        outcomes = await categorize_batch(rows, categories, settings, client=client)
        for row, outcome in zip(rows, outcomes, strict=True):
            if outcome.status == "assigned":
                row.category_id = outcome.category_id
                row.categorization_source = "model"
                row.categorization_confidence = outcome.confidence
                row.needs_review = False
            # A deferred or failed row is left exactly as it was: it stays in the review
            # queue, which is where it already was.
            run.processed_count += 1
            if outcome.status == "assigned":
                run.assigned_count += 1
            elif outcome.status == "deferred":
                run.deferred_count += 1
            else:
                run.failed_count += 1

        # Per batch, not at the end: a process killed here keeps every row applied so far and
        # a `processed_count` that still tells the truth about them (`PROJECT.md` §7).
        repository.commit()

    run.status = _terminal_status(run)
    if run.status == "failed":
        run.error_message = RUNTIME_UNREACHABLE_MESSAGE
    run.finished_at = datetime.now(UTC)
    repository.commit()


def _terminal_status(run: CategorizationRun) -> str:
    """Resolve the status a finished run settles on.

    `failed` is reserved for a run that got nowhere — every row it attempted came back a
    runtime failure, which in practice means the runtime was unreachable throughout. A run
    that placed even one row worked, and reports `partial` so the failures stay visible
    without the successes being disowned.
    """
    if run.failed_count == 0:
        return "success"
    if run.failed_count == run.processed_count:
        return "failed"
    return "partial"


def _locale(db: Session, user_id: str) -> str:
    """The user's locale, which decides the language the category list is offered in."""
    user = db.get(User, user_id)
    return user.locale if user is not None else "fr"


def _fail_quietly(session_factory: SessionFactory, run_id: str, message: str) -> None:
    """Record an unexpected failure on the run, on a session known not to be poisoned.

    The session the run died on may hold a broken transaction, so the status is written
    through a fresh one. If even that fails there is nothing further to try — startup
    reconciliation will catch the run on the next boot.
    """
    db = session_factory()
    try:
        run = db.get(CategorizationRun, run_id)
        if run is not None and run.status in ("pending", "running"):
            run.status = "failed"
            run.error_message = message[:1000]
            run.finished_at = datetime.now(UTC)
            db.commit()
    except Exception:
        logger.exception("Could not record the failure of categorization run %s.", run_id)
    finally:
        db.close()
