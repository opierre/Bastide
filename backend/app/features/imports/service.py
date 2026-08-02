"""Business logic for OFX/QFX import: parse, normalize, dedup, persist atomically."""

import hashlib
from calendar import monthrange
from collections.abc import Callable
from datetime import date
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.features.accounts.balance import apply_delta, point_in_time_balance
from app.features.accounts.models import Account, AccountBalanceSnapshot
from app.features.accounts.service import AccountService
from app.features.auth.models import User
from app.features.imports.canonical import CanonicalTransaction, normalize
from app.features.imports.models import ImportBatch
from app.features.imports.parsers.ofx import OfxParseError
from app.features.imports.parsers.ofx import parse as parse_ofx
from app.features.imports.repository import ImportRepository
from app.features.transactions.models import Transaction

_QFX_EXTENSION = ".qfx"


class ImportBatchNotFoundError(NotFoundError):
    """Raised when an import batch doesn't exist or doesn't belong to the caller."""

    code = "IMPORT_BATCH_NOT_FOUND"


class ImportService:
    """Parses an uploaded OFX/QFX file into the ledger, atomically, once per unique file."""

    def __init__(
        self,
        repository: ImportRepository,
        account_service: AccountService,
        db: Session,
        clock: Callable[[], date] = date.today,
    ) -> None:
        self._repository = repository
        self._account_service = account_service
        self._db = db
        self._clock = clock

    def list_for_user(self, user_id: str) -> list[ImportBatch]:
        """List a user's import batches, most recent first (the import history)."""
        return self._repository.list_by_user(user_id)

    def get(self, user_id: str, batch_id: str) -> ImportBatch:
        """Fetch a single import batch the user owns.

        Raises:
            ImportBatchNotFoundError: no such batch, or it belongs to another user.
        """
        batch = self._repository.get_by_id_for_user(batch_id, user_id)
        if batch is None:
            raise ImportBatchNotFoundError("Import batch not found.")
        return batch

    def import_file(
        self, user: User, account_id: str, file_name: str, content: bytes
    ) -> ImportBatch:
        """Import an OFX/QFX file into ``account_id``, scoped to ``user``.

        Raises:
            AccountNotFoundError: no such account, or it belongs to another user.
        """
        account = self._account_service.get(user.id, account_id)
        file_hash = hashlib.sha256(content).hexdigest()

        existing_batch = self._repository.find_batch_by_file_hash(account.id, file_hash)
        if existing_batch is not None:
            return existing_batch

        source_format = "qfx" if file_name.lower().endswith(_QFX_EXTENSION) else "ofx"

        try:
            raw_transactions = parse_ofx(content)
        except OfxParseError as exc:
            return self._repository.save(
                ImportBatch(
                    id=str(uuid4()),
                    user_id=user.id,
                    account_id=account.id,
                    source_format=source_format,
                    file_name=file_name,
                    file_hash=file_hash,
                    period_start=self._clock(),
                    period_end=self._clock(),
                    transaction_count=0,
                    new_count=0,
                    duplicate_count=0,
                    status="failed",
                    error_message=str(exc),
                ),
                transactions=[],
            )

        canonical_transactions = [
            normalize(raw, account_id=account.id, currency=account.currency)
            for raw in raw_transactions
        ]

        today = self._clock()
        period_start = min((t.booked_date for t in canonical_transactions), default=today)
        period_end = max((t.booked_date for t in canonical_transactions), default=today)

        new_rows, duplicate_count = self._dedup(account.id, canonical_transactions)

        batch = ImportBatch(
            id=str(uuid4()),
            user_id=user.id,
            account_id=account.id,
            source_format=source_format,
            file_name=file_name,
            file_hash=file_hash,
            period_start=period_start,
            period_end=period_end,
            transaction_count=len(canonical_transactions),
            new_count=len(new_rows),
            duplicate_count=duplicate_count,
            status="success",
        )

        new_transactions = [
            Transaction(
                account_id=account.id,
                import_batch_id=batch.id,
                booked_date=row.booked_date,
                value_date=row.value_date,
                amount_minor=row.amount_minor,
                currency=row.currency,
                description_raw=row.description_raw,
                description_clean=row.description_clean,
                merchant=row.merchant,
                category_id=None,
                categorization_source="uncategorized",
                needs_review=True,
                fitid=row.fitid,
                dedup_hash=row.dedup_hash,
            )
            for row in new_rows
        ]

        self._db.add_all(new_transactions)
        self._db.flush()

        delta_minor = sum(row.amount_minor for row in new_rows)
        apply_delta(account, delta_minor)
        if new_rows:
            self._sync_month_boundary_snapshots(account, period_start, period_end)

        return self._repository.save(batch, new_transactions)

    def _dedup(
        self, account_id: str, canonical_transactions: list[CanonicalTransaction]
    ) -> tuple[list[CanonicalTransaction], int]:
        """Split canonical rows into new vs. duplicate, per the fitid-else-hash dedup rule.

        Checks both rows already booked on the account and repeats within this same file.
        """
        fitids = [t.fitid for t in canonical_transactions if t.fitid is not None]
        hashes = [t.dedup_hash for t in canonical_transactions if t.fitid is None]
        seen_fitids = self._repository.existing_fitids(account_id, fitids)
        seen_hashes = self._repository.existing_dedup_hashes(account_id, hashes)

        new_rows: list[CanonicalTransaction] = []
        duplicate_count = 0
        for row in canonical_transactions:
            if row.fitid is not None:
                is_duplicate = row.fitid in seen_fitids
                if not is_duplicate:
                    seen_fitids.add(row.fitid)
            else:
                is_duplicate = row.dedup_hash in seen_hashes
                if not is_duplicate:
                    seen_hashes.add(row.dedup_hash)

            if is_duplicate:
                duplicate_count += 1
            else:
                new_rows.append(row)

        return new_rows, duplicate_count

    def _sync_month_boundary_snapshots(
        self, account: Account, period_start: date, period_end: date
    ) -> None:
        """Write/refresh a monthly snapshot for each calendar month this import closes.

        A month only "closes" once the import has rows past its end, so the in-progress final
        month (period_end's own month) is never snapshotted here.
        """
        year, month = period_start.year, period_start.month
        while (year, month) < (period_end.year, period_end.month):
            month_end = date(year, month, monthrange(year, month)[1])
            snapshot = self._db.scalar(
                select(AccountBalanceSnapshot).where(
                    AccountBalanceSnapshot.account_id == account.id,
                    AccountBalanceSnapshot.period_end == month_end,
                )
            )
            balance_minor = point_in_time_balance(self._db, account, month_end)
            if snapshot is None:
                self._db.add(
                    AccountBalanceSnapshot(
                        account_id=account.id, period_end=month_end, balance_minor=balance_minor
                    )
                )
            else:
                snapshot.balance_minor = balance_minor

            if month == 12:
                year, month = year + 1, 1
            else:
                month += 1
