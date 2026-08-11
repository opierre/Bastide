"""Data access for `CategorizationRun` rows and the transactions a run may reconsider.

The only place either query lives. Two of them carry rules that are the feature's correctness,
not conveniences: `insert_unless_in_flight` enforces one run per user *inside the insert*, and
`select_candidate_ids` is the single gate that keeps `user` and `rule` rows away from the model.
"""

from datetime import UTC, datetime
from typing import Any
from uuid import uuid4

from sqlalchemy import Select, and_, insert, literal, or_, select, update
from sqlalchemy.orm import Session
from sqlalchemy.sql.dml import Insert

from app.core.db import Base
from app.features.accounts.models import Account
from app.features.categorization.models import CategorizationRun
from app.features.categorization.schemas import RunScope
from app.features.transactions.models import Transaction

#: The two statuses that mean a run still owns the user's rows.
ACTIVE_STATUSES = ("pending", "running")

# SQLite caps the parameters of one statement; run selections are re-read by id in chunks so a
# large run never builds an `IN (...)` list longer than that.
_ID_CHUNK_SIZE = 500


class CategorizationRunRepository:
    """Queries and writes for categorisation runs, always scoped to a user."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def select_candidate_ids(
        self, user_id: str, scope: RunScope, account_id: str | None = None
    ) -> list[str]:
        """Return the ids of the transactions a run of ``scope`` would reconsider.

        `source='user'` and `source='rule'` rows are excluded by construction rather than
        filtered out later: user intent and a deterministic rule both outrank the model
        (`PROJECT.md` §7), so there is no branch anywhere that could let one through.

        Args:
            user_id: the owner; the join to `accounts` is what scopes the query.
            scope: `pending` for rows nothing has categorised yet; `all` additionally takes
                rows a previous run assigned, for a re-run after changing model or threshold.
            account_id: narrows to one account; `None` covers every account.
        """
        uncategorized = and_(
            Transaction.needs_review.is_(True),
            Transaction.categorization_source == "uncategorized",
        )
        selector = (
            uncategorized
            if scope == "pending"
            else or_(uncategorized, Transaction.categorization_source == "model")
        )

        query = (
            select(Transaction.id)
            .join(Account, Account.id == Transaction.account_id)
            .where(Account.user_id == user_id, selector)
            .order_by(Transaction.booked_date, Transaction.id)
        )
        if account_id is not None:
            query = query.where(Transaction.account_id == account_id)
        return list(self._db.scalars(query))

    def list_transactions(self, user_id: str, transaction_ids: list[str]) -> list[Transaction]:
        """Load the given transactions, in the order asked for, scoped to ``user_id``.

        Ids the user does not own simply do not come back — the join, not the caller, is what
        guarantees that.
        """
        by_id: dict[str, Transaction] = {}
        for start in range(0, len(transaction_ids), _ID_CHUNK_SIZE):
            chunk = transaction_ids[start : start + _ID_CHUNK_SIZE]
            rows = self._db.scalars(
                select(Transaction)
                .join(Account, Account.id == Transaction.account_id)
                .where(Account.user_id == user_id, Transaction.id.in_(chunk))
            )
            by_id.update({row.id: row for row in rows})
        return [by_id[row_id] for row_id in transaction_ids if row_id in by_id]

    def insert_unless_in_flight(self, run: CategorizationRun) -> CategorizationRun:
        """Insert ``run`` unless the user already has one in flight; return whichever holds.

        The check and the insert are one statement — `INSERT … SELECT … WHERE NOT EXISTS` —
        rather than a read followed by a write. A check-then-insert has a window between the
        two in which a second request passes the same check, and two runs over the same rows
        would race on `category_id` (`PROJECT.md` §7). Here the database evaluates the
        condition and the insert together, so at most one of them can win.
        """
        for _ in range(2):
            self._db.execute(self._conditional_insert(run))
            self._db.commit()
            in_flight = self.find_in_flight(run.user_id)
            if in_flight is not None:
                return in_flight
            # The insert was blocked by a run that finished before we could read it back.
            # Nothing owns the rows now, so the one retry inserts unopposed.
        raise RuntimeError("Could not start a categorization run.")

    def find_in_flight(self, user_id: str) -> CategorizationRun | None:
        """The user's `pending`/`running` run, if there is one. At most one can exist."""
        return self._db.scalar(
            select(CategorizationRun)
            .where(
                CategorizationRun.user_id == user_id,
                CategorizationRun.status.in_(ACTIVE_STATUSES),
            )
            .order_by(CategorizationRun.created_at.desc())
        )

    def list_by_user(self, user_id: str, limit: int) -> list[CategorizationRun]:
        """A user's run history, newest first."""
        return list(
            self._db.scalars(
                select(CategorizationRun)
                .where(CategorizationRun.user_id == user_id)
                .order_by(CategorizationRun.created_at.desc(), CategorizationRun.id.desc())
                .limit(limit)
            )
        )

    def get_by_id_for_user(self, run_id: str, user_id: str) -> CategorizationRun | None:
        return self._db.scalar(
            select(CategorizationRun).where(
                CategorizationRun.id == run_id, CategorizationRun.user_id == user_id
            )
        )

    def read_status(self, run_id: str) -> str | None:
        """Re-read one run's status from the database, bypassing this session's cached row.

        The executor calls this between batches to notice a cancellation written by the
        request that served `POST /runs/{id}/cancel` — a different session on a different
        connection. It is only visible because the executor commits each batch, ending its
        read transaction and starting a fresh one on the next statement.
        """
        return self._db.scalar(
            select(CategorizationRun.status).where(CategorizationRun.id == run_id)
        )

    def commit(self) -> None:
        """Commit pending changes — the per-batch progress write."""
        self._db.commit()

    def fail_orphaned(self, message: str) -> int:
        """Mark every still-in-flight run `failed`; return how many there were.

        Called once at startup. A run left `pending`/`running` has no executor — that died
        with the previous process — so leaving it in flight would both lie to the progress UI
        and block every future run behind a one-at-a-time check nothing can ever release.
        """
        orphaned = list(
            self._db.scalars(
                select(CategorizationRun.id).where(CategorizationRun.status.in_(ACTIVE_STATUSES))
            )
        )
        if not orphaned:
            return 0

        self._db.execute(
            update(CategorizationRun)
            .where(CategorizationRun.id.in_(orphaned))
            .values(status="failed", error_message=message, finished_at=datetime.now(UTC))
        )
        self._db.commit()
        return len(orphaned)

    def _conditional_insert(self, run: CategorizationRun) -> Insert:
        """Build `INSERT … SELECT <run> WHERE NOT EXISTS (<an in-flight run>)`."""
        table = Base.metadata.tables[CategorizationRun.__tablename__]
        values: dict[str, Any] = {
            "id": run.id,
            "user_id": run.user_id,
            "account_id": run.account_id,
            "import_batch_id": run.import_batch_id,
            "trigger": run.trigger,
            "status": run.status,
            "model_tag": run.model_tag,
            "total_count": run.total_count,
            "processed_count": run.processed_count,
            "assigned_count": run.assigned_count,
            "deferred_count": run.deferred_count,
            "failed_count": run.failed_count,
            "error_message": run.error_message,
            "started_at": run.started_at,
            "finished_at": run.finished_at,
            "created_at": run.created_at,
        }
        in_flight = (
            select(CategorizationRun.id)
            .where(
                CategorizationRun.user_id == run.user_id,
                CategorizationRun.status.in_(ACTIVE_STATUSES),
            )
            .exists()
        )
        projection: Select[Any] = select(
            *(literal(value, table.c[name].type).label(name) for name, value in values.items())
        ).where(~in_flight)
        return insert(table).from_select(list(values), projection)


def new_run(
    user_id: str,
    *,
    trigger: str,
    account_id: str | None,
    import_batch_id: str | None,
    model_tag: str | None,
    total_count: int,
) -> CategorizationRun:
    """Build a `pending` run with every column populated.

    The id and timestamp are generated here rather than left to the column defaults because
    `insert_unless_in_flight` inserts through a `SELECT` projection, which never invokes them.
    """
    return CategorizationRun(
        id=str(uuid4()),
        user_id=user_id,
        account_id=account_id,
        import_batch_id=import_batch_id,
        trigger=trigger,
        status="pending",
        model_tag=model_tag,
        total_count=total_count,
        processed_count=0,
        assigned_count=0,
        deferred_count=0,
        failed_count=0,
        error_message=None,
        started_at=None,
        finished_at=None,
        created_at=datetime.now(UTC),
    )
