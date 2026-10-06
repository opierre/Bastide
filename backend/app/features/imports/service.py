"""Business logic for OFX/QFX import: parse, normalize, dedup, persist atomically."""

import hashlib
from calendar import monthrange
from collections.abc import Callable
from datetime import date
from typing import Protocol
from uuid import uuid4

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.features.accounts.balance import apply_delta, point_in_time_balance, shift_opening_balance
from app.features.accounts.models import Account, AccountBalanceSnapshot
from app.features.accounts.service import AccountService
from app.features.auth.models import User
from app.features.imports.canonical import CanonicalTransaction, normalize
from app.features.imports.models import ImportBatch
from app.features.imports.parsers.ofx import LedgerBalance, OfxParseError, parse_ledger_balance
from app.features.imports.parsers.ofx import parse as parse_ofx
from app.features.imports.repository import ImportRepository
from app.features.rules.engine import match_category
from app.features.rules.repository import RuleRepository
from app.features.transactions.models import Transaction

_QFX_EXTENSION = ".qfx"


class RunEnqueuer(Protocol):
    """Starts stage-2 categorisation over what an import left for review.

    A protocol rather than a direct call into the categorisation feature: the import pipeline
    has no business knowing a model exists, and stating the dependency this narrowly is what
    lets an import with no enqueuer wired behave as a rules-only import.

    Implementations must be silent — an import that has already committed cannot be failed by
    anything that happens after it (`PROJECT.md` §7).
    """

    def __call__(self, user: User, account_id: str, import_batch_id: str) -> None: ...


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
        run_enqueuer: RunEnqueuer | None = None,
    ) -> None:
        self._repository = repository
        self._account_service = account_service
        self._db = db
        self._clock = clock
        # Absent means stage 2 is simply not wired here: the import behaves as it did before
        # the model existed, which is also what every test constructing this service without
        # one gets.
        self._run_enqueuer = run_enqueuer

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
        self,
        user: User,
        account_id: str,
        file_name: str,
        content: bytes,
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

        had_transactions = self._has_transactions(account.id)
        source_format = "qfx" if file_name.lower().endswith(_QFX_EXTENSION) else "ofx"

        # A statement declares where the account stands, not just how it moved — but the
        # tag is optional, so this stays None for an exporter that omits `LEDGERBAL`.
        declared_balance: LedgerBalance | None = None
        try:
            raw_transactions = parse_ofx(content)
            declared_balance = parse_ledger_balance(content)
        except OfxParseError as exc:
            return self._repository.save(
                self._failed_batch(user, account, source_format, file_name, file_hash, exc),
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
        rules = RuleRepository(self._db).list_enabled_by_user(user.id)

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

        new_transactions = []
        for row in new_rows:
            transaction = Transaction(
                account_id=account.id,
                import_batch_id=batch.id,
                booked_date=row.booked_date,
                value_date=row.value_date,
                amount_minor=row.amount_minor,
                currency=row.currency,
                description_raw=row.description_raw,
                description_clean=row.description_clean,
                memo=row.memo,
                merchant=row.merchant,
                category_id=None,
                categorization_source="uncategorized",
                needs_review=True,
                fitid=row.fitid,
                dedup_hash=row.dedup_hash,
            )
            matched_category_id = match_category(transaction, rules)
            if matched_category_id is not None:
                transaction.category_id = matched_category_id
                transaction.categorization_source = "rule"
                transaction.needs_review = False
            new_transactions.append(transaction)

        self._db.add_all(new_transactions)
        self._db.flush()

        delta_minor = sum(row.amount_minor for row in new_rows)
        apply_delta(account, delta_minor)

        # Before any snapshot is written, so they are taken from the corrected base.
        if declared_balance is not None:
            if had_transactions:
                self._detect_balance_mismatch(
                    batch, account, declared_balance, fallback_as_of=period_end
                )
            else:
                self._reconcile_opening_balance(
                    account, declared_balance, fallback_as_of=period_end
                )

        if new_rows:
            self._sync_month_boundary_snapshots(account, period_start, period_end)

        saved = self._repository.save(batch, new_transactions)

        # Only once the batch has committed, and only from the success path: a run over rows
        # that were never persisted would have nothing to categorise. The import does not wait
        # on the model — the enqueuer starts the run and returns (`PROJECT.md` §7).
        if self._run_enqueuer is not None:
            self._run_enqueuer(user, account.id, saved.id)

        return saved

    def _failed_batch(
        self,
        user: User,
        account: Account,
        source_format: str,
        file_name: str,
        file_hash: str,
        exc: Exception,
    ) -> ImportBatch:
        """Build a `failed` batch record for a file that couldn't be parsed at all."""
        return ImportBatch(
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
        )

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

    def _has_transactions(self, account_id: str) -> bool:
        """Whether the account already has a ledger — i.e. this import isn't its first."""
        return (
            self._db.scalar(
                select(Transaction.id).where(Transaction.account_id == account_id).limit(1)
            )
            is not None
        )

    def _reconcile_opening_balance(
        self, account: Account, declared: LedgerBalance, fallback_as_of: date
    ) -> None:
        """Derive the account's opening balance from the balance the statement declares.

        `opening_balance_minor` is the seed the ledger is added to, so it means "what
        this account held before its first transaction" — a figure nobody can look up.
        Asked for it directly, a user reasonably types today's balance instead, and every
        transaction in the statement then gets counted twice. The statement already knows
        the answer, so we work backwards from it::

            opening = declared balance − (rows booked on or before its as-of date)

        **Only on an account's first import**, deliberately. A later statement's balance
        is equally true, but re-deriving from it would silently absorb any gap in the
        ledger (months the user never imported) into the opening balance, moving the
        error rather than fixing it. Once there is history, `_detect_balance_mismatch`
        compares against it instead of overwriting it.
        """
        as_of = declared.as_of or fallback_as_of
        booked_through = (
            self._db.scalar(
                select(func.coalesce(func.sum(Transaction.amount_minor), 0)).where(
                    Transaction.account_id == account.id,
                    Transaction.booked_date <= as_of,
                )
            )
            or 0
        )

        shift_opening_balance(self._db, account, declared.amount_minor - booked_through)

    def _detect_balance_mismatch(
        self,
        batch: ImportBatch,
        account: Account,
        declared: LedgerBalance,
        fallback_as_of: date,
    ) -> None:
        """Compare a statement's declared balance against what the ledger implies.

        Runs from an account's *second* import onward — the first derives the opening
        balance from this same figure instead (`_reconcile_opening_balance`), so there is
        nothing yet to compare it to. A non-zero gap means the bank and the ledger
        disagree — a missed statement, an un-imported gap, or a bad prior correction — and
        it is recorded on the batch rather than absorbed into the opening balance or the
        cache, so the user sees it and can decide how to fix it (e.g. patch
        `opening_balance_minor`, or track down the missing transactions).
        """
        as_of = declared.as_of or fallback_as_of
        implied = point_in_time_balance(self._db, account, as_of)
        mismatch = declared.amount_minor - implied
        if mismatch != 0:
            batch.balance_mismatch_minor = mismatch
            batch.balance_mismatch_as_of = as_of

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
