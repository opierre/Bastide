"""Data access for import batches and the transactions an import creates."""

from sqlalchemy import select
from sqlalchemy.orm import Session

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
