"""Data access for import batches and the transactions an import creates."""

from datetime import date

from sqlalchemy import exists, or_, select
from sqlalchemy.orm import Session, aliased

from app.features.accounts.models import Account
from app.features.imports.models import ImportBatch
from app.features.transactions.models import Transaction


class ImportRepository:
    """Queries and writes for import batches, always scoped to a user or account."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def find_batch_by_file_hash(self, account_id: str, file_hash: str) -> ImportBatch | None:
        return self._db.scalar(
            select(ImportBatch).where(
                ImportBatch.account_id == account_id, ImportBatch.file_hash == file_hash
            )
        )

    def list_by_user(self, user_id: str) -> list[ImportBatch]:
        return list(
            self._db.scalars(
                select(ImportBatch)
                .where(ImportBatch.user_id == user_id)
                .order_by(ImportBatch.imported_at.desc())
            )
        )

    def get_by_id_for_user(self, batch_id: str, user_id: str) -> ImportBatch | None:
        return self._db.scalar(
            select(ImportBatch).where(ImportBatch.id == batch_id, ImportBatch.user_id == user_id)
        )

    def existing_fitids(self, account_id: str, fitids: list[str]) -> set[str]:
        """Which of these `fitid`s are already booked on this account."""
        if not fitids:
            return set()
        rows = self._db.scalars(
            select(Transaction.fitid).where(
                Transaction.account_id == account_id, Transaction.fitid.in_(fitids)
            )
        )
        return {row for row in rows if row is not None}

    def existing_dedup_hashes(self, account_id: str, dedup_hashes: list[str]) -> set[str]:
        """Which of these `dedup_hash`es are already booked on this account."""
        if not dedup_hashes:
            return set()
        rows = self._db.scalars(
            select(Transaction.dedup_hash).where(
                Transaction.account_id == account_id,
                Transaction.dedup_hash.in_(dedup_hashes),
            )
        )
        return set(rows)

    def unlinked_settlement_candidates(
        self, user_id: str, settlement_category_id: str
    ) -> list[Transaction]:
        """Debits on the user's non-card accounts that could be an unmatched card settlement.

        Rows already filed as a settlement, plus uncategorised rows the user hasn't touched —
        a settlement imported before its card account existed was left uncategorised, and the
        caller re-reads its label. Rows a cycle already references are matched and excluded.
        """
        claimed = aliased(Transaction)
        return list(
            self._db.scalars(
                select(Transaction)
                .join(Account, Transaction.account_id == Account.id)
                .where(
                    Account.user_id == user_id,
                    Account.type != "deferred_card",
                    Account.archived.is_(False),
                    Transaction.amount_minor < 0,
                    or_(
                        Transaction.category_id == settlement_category_id,
                        Transaction.category_id.is_(None)
                        & (Transaction.categorization_source != "user"),
                    ),
                    ~exists().where(claimed.card_settlement_id == Transaction.id),
                )
                .order_by(Transaction.booked_date, Transaction.id)
            )
        )

    def unsettled_card_rows(self, account_id: str, through: date) -> list[Transaction]:
        """A card's rows no settlement has claimed yet, booked up to ``through``, oldest first."""
        return list(
            self._db.scalars(
                select(Transaction)
                .where(
                    Transaction.account_id == account_id,
                    Transaction.card_settlement_id.is_(None),
                    Transaction.booked_date <= through,
                )
                .order_by(Transaction.booked_date, Transaction.id)
            )
        )

    def find_card_reset(
        self, account_id: str, amount_minor: int, start: date, end: date
    ) -> Transaction | None:
        """An unclaimed credit of exactly ``amount_minor`` on the card between the two dates.

        Some banks print the settlement on the card's own statement as a credit resetting the
        cycle; when it is there, it is the offset, and posting another would count it twice.
        """
        return self._db.scalar(
            select(Transaction)
            .where(
                Transaction.account_id == account_id,
                Transaction.card_settlement_id.is_(None),
                Transaction.amount_minor == amount_minor,
                Transaction.booked_date >= start,
                Transaction.booked_date <= end,
            )
            .order_by(Transaction.booked_date)
            .limit(1)
        )

    def save(self, batch: ImportBatch, transactions: list[Transaction]) -> ImportBatch:
        """Persist the batch and its new transactions in one DB transaction.

        The account whose balance/snapshots were updated alongside these rows is expected to
        already be attached to the same session, so it commits atomically with everything here.
        """
        self._db.add(batch)
        self._db.add_all(transactions)
        self._db.commit()
        self._db.refresh(batch)
        return batch
