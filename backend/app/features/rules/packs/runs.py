"""Rule pack imports run in the background, publishing their logo download progress.

Importing a pack that links logos waits on Wikimedia, two downloads at a time with backoff,
for up to `DOWNLOAD_DEADLINE_S`. So the request only starts a run and returns its id; the run
imports the rules, then downloads the logos, and reports each settled download on the progress
bus (`kind="rule_pack_import"`). The run's snapshot, final result included, is read back with
`GET /rules/packs/import-runs/{id}`.

Runs are kept in memory, not in a table. A run's lasting effect, the rules and logos, is
committed to the database as it goes; what is kept here is only the report of it, which the app
reads within moments of the run ending. A process that stops mid-run takes its executor with it
anyway, so a persisted row would only ever say "interrupted", and the in-process progress bus
makes the same trade. The store keeps the latest few runs per user, so it cannot grow unbounded.
"""

import asyncio
import logging
import threading
import uuid
from collections.abc import Callable, Coroutine
from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any

from app.core.db import SessionFactory
from app.core.errors import ConflictError, NotFoundError
from app.core.progress import ProgressBus, RunReporter
from app.features.rules.packs.download import LogoFetcher
from app.features.rules.packs.schema import (
    RulePack,
    RulePackImportResult,
    RulePackImportRunRead,
    RulePackImportRunStatus,
)
from app.features.rules.packs.service import ImportedRules, PackImport, build_pack_service

logger = logging.getLogger(__name__)

#: The run kind pack imports publish under on the progress bus.
RUN_KIND = "rule_pack_import"
#: Runs remembered per user; the oldest settled ones are forgotten past this.
MAX_RUNS_PER_USER = 20
#: What a run that could not finish reports. User-safe: the cause goes to the log only.
IMPORT_FAILED_MESSAGE = "The rule pack import could not finish."

#: Hands a coroutine off to run detached from the request that created it. Injected so tests
#: drive the executor when they choose instead of racing the event loop.
type PackImportLauncher = Callable[[Coroutine[Any, Any, None]], None]

# Held for as long as they run: asyncio keeps only a weak reference to a task.
_background_tasks: set[asyncio.Task[None]] = set()


class PackImportRunNotFoundError(NotFoundError):
    """Raised when a pack import run doesn't exist, is forgotten, or isn't the caller's."""

    code = "RULE_PACK_IMPORT_RUN_NOT_FOUND"


class PackImportInProgressError(ConflictError):
    """Raised when starting an import while another of the user's is still running.

    Two imports at once would each deduplicate against the rules the other has not committed
    yet, and could both create the same rule.
    """

    code = "RULE_PACK_IMPORT_IN_PROGRESS"


@dataclass(eq=False)
class PackImportRun:
    """One background import: where its logo downloads are, then what it did."""

    id: str
    user_id: str
    created_at: datetime
    status: RulePackImportRunStatus = "running"
    logo_done: int = 0
    logo_total: int = 0
    counts: dict[str, int] = field(default_factory=dict)
    result: RulePackImportResult | None = None
    error_message: str | None = None
    finished_at: datetime | None = None

    def to_read(self) -> RulePackImportRunRead:
        return RulePackImportRunRead(
            id=self.id,
            status=self.status,
            logo_done=self.logo_done,
            logo_total=self.logo_total,
            result=self.result,
            error_message=self.error_message,
            created_at=self.created_at,
            finished_at=self.finished_at,
        )


class PackImportRunStore:
    """The in-memory record of each user's recent pack import runs."""

    def __init__(self, max_runs_per_user: int = MAX_RUNS_PER_USER) -> None:
        self._lock = threading.Lock()
        self._runs: dict[str, dict[str, PackImportRun]] = {}
        self._max = max_runs_per_user

    def start(self, user_id: str, now: datetime) -> PackImportRun:
        """Record a new running import for ``user_id``.

        Raises:
            PackImportInProgressError: the user already has one running.
        """
        with self._lock:
            runs = self._runs.setdefault(user_id, {})
            if any(run.status == "running" for run in runs.values()):
                raise PackImportInProgressError("A rule pack import is already running.")
            run = PackImportRun(id=str(uuid.uuid4()), user_id=user_id, created_at=now)
            runs[run.id] = run
            # Dicts keep insertion order, so the first settled runs are the oldest.
            settled = [key for key, old in runs.items() if old.status != "running"]
            for key in settled[: max(0, len(runs) - self._max)]:
                del runs[key]
            return run

    def get(self, user_id: str, run_id: str) -> PackImportRun | None:
        with self._lock:
            return self._runs.get(user_id, {}).get(run_id)


_store = PackImportRunStore()


def get_pack_import_run_store() -> PackImportRunStore:
    """The process-wide store, as a dependency so tests can hand in their own."""
    return _store


def launch_in_background(coro: Coroutine[Any, Any, None]) -> None:
    """Schedule ``coro`` on the running loop and return at once."""
    task = asyncio.create_task(coro)
    _background_tasks.add(task)
    task.add_done_callback(_background_tasks.discard)


def get_pack_import_launcher() -> PackImportLauncher:
    """The launcher dependency; overridden in tests to make execution deterministic."""
    return launch_in_background


class PackImportRunService:
    """Starts pack imports in the background and reads their snapshots."""

    def __init__(
        self,
        store: PackImportRunStore,
        session_factory: SessionFactory,
        launcher: PackImportLauncher,
        logo_fetcher: LogoFetcher,
        bus: ProgressBus,
        clock: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._store = store
        self._session_factory = session_factory
        self._launcher = launcher
        self._logo_fetcher = logo_fetcher
        self._bus = bus
        self._clock = clock

    def start(
        self,
        user_id: str,
        pack: RulePack,
        apply_now: bool,
        download_logos: bool,
        builtin_id: str | None = None,
    ) -> PackImportRun:
        """Start importing ``pack`` for the user and return the running import at once.

        ``builtin_id`` names the bundled pack, if it is one, so the import records it.

        Raises:
            PackImportInProgressError: another of the user's imports is still running.
        """
        run = self._store.start(user_id, self._clock())
        self._launcher(
            execute_pack_import(
                run,
                pack,
                apply_now,
                download_logos,
                session_factory=self._session_factory,
                logo_fetcher=self._logo_fetcher,
                bus=self._bus,
                clock=self._clock,
                builtin_id=builtin_id,
            )
        )
        return run

    def get(self, user_id: str, run_id: str) -> PackImportRun:
        """The snapshot of one of the user's imports.

        Raises:
            PackImportRunNotFoundError: no such run, forgotten, or another user's.
        """
        run = self._store.get(user_id, run_id)
        if run is None:
            raise PackImportRunNotFoundError("Rule pack import run not found.")
        return run


class _RunProgress:
    """Keeps a run's snapshot and the progress bus in step with the import."""

    def __init__(self, run: PackImportRun, reporter: RunReporter) -> None:
        self._run = run
        self._reporter = reporter
        self._download_failed = 0

    def rules_imported(self, rules: ImportedRules, logo_total: int) -> None:
        run = self._run
        run.logo_total = logo_total
        run.counts = {
            "created": rules.created_count,
            "skipped": rules.skipped_count,
            "unresolved": rules.unresolved_count,
            "recategorized": rules.recategorized_count,
            "downloaded": 0,
            "download_failed": 0,
        }
        self._reporter.started(logo_total, counts=run.counts)

    def logo_fetched(self, *, failed: bool) -> None:
        run = self._run
        run.logo_done += 1
        key = "download_failed" if failed else "downloaded"
        run.counts = {**run.counts, key: run.counts.get(key, 0) + 1}
        self._reporter.progress(run.logo_done, run.logo_total, counts=run.counts)


async def execute_pack_import(
    run: PackImportRun,
    pack: RulePack,
    apply_now: bool,
    download_logos: bool,
    *,
    session_factory: SessionFactory,
    logo_fetcher: LogoFetcher,
    bus: ProgressBus,
    clock: Callable[[], datetime] = lambda: datetime.now(UTC),
    builtin_id: str | None = None,
) -> None:
    """Import ``pack`` on a session of its own, settling ``run`` and publishing each step.

    Never raises: there is no caller left to tell, so a failure is recorded on the run and
    published as its `failed` event.
    """
    reporter = RunReporter(bus, run.user_id, run.id, RUN_KIND)
    progress = _RunProgress(run, reporter)
    db = session_factory()
    try:
        outcome = await build_pack_service(db, logo_fetcher).import_pack(
            run.user_id, pack, apply_now, download_logos, progress, builtin_id=builtin_id
        )
    except Exception:  # noqa: BLE001 — the last frame before the task is discarded.
        logger.exception("Rule pack import run %s failed.", run.id)
        run.status = "failed"
        run.error_message = IMPORT_FAILED_MESSAGE
        run.finished_at = clock()
        reporter.failed(run.logo_done, run.logo_total, IMPORT_FAILED_MESSAGE, counts=run.counts)
        return
    finally:
        db.close()

    run.result = _result(outcome)
    run.counts = _final_counts(outcome)
    run.status = "finished"
    run.finished_at = clock()
    reporter.finished(run.logo_done, run.logo_total, counts=run.counts)


def _result(outcome: PackImport) -> RulePackImportResult:
    return RulePackImportResult(
        created_count=outcome.created_count,
        skipped_count=outcome.skipped_count,
        unresolved=outcome.unresolved,
        recategorized_count=outcome.recategorized_count,
        logo_count=outcome.logo_count,
        logo_skipped_count=outcome.logo_skipped_count,
        logo_failures=outcome.logo_failures,
    )


def _final_counts(outcome: PackImport) -> dict[str, int]:
    """The `finished` event's tallies: the result's numbers, logo failures as a count."""
    return {
        "created": outcome.created_count,
        "skipped": outcome.skipped_count,
        "unresolved": len(outcome.unresolved),
        "recategorized": outcome.recategorized_count,
        "logos": outcome.logo_count,
        "logos_skipped": outcome.logo_skipped_count,
        "logos_failed": len(outcome.logo_failures),
    }
