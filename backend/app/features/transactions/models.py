"""SQLAlchemy model for transactions, the ledger and single source of truth for balances."""

from datetime import UTC, date, datetime
from uuid import uuid4

from sqlalchemy import Boolean, Date, DateTime, Float, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Transaction(Base):
    """A single ledger entry. ``amount_minor`` is signed: negative = outflow.

    Dedup: unique on ``(account_id, fitid)`` when ``fitid`` is present (NULLs are distinct
    under SQL unique semantics, so multiple fitid-less rows are still allowed). Rows without a
    ``fitid`` (CSV imports) are deduped by ``dedup_hash`` in the import service instead of a DB
    constraint, since the hash alone can legitimately collide between two real transactions with
    a fitid — see the database skill.
    """

    __tablename__ = "transactions"
    __table_args__ = (
        Index("ix_transactions_account_fitid", "account_id", "fitid", unique=True),
        Index("ix_transactions_account_dedup_hash", "account_id", "dedup_hash"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    account_id: Mapped[str] = mapped_column(String(36), ForeignKey("accounts.id"), index=True)
    import_batch_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("import_batches.id"), index=True
    )
    booked_date: Mapped[date] = mapped_column(Date)
    value_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    amount_minor: Mapped[int] = mapped_column(Integer)
    currency: Mapped[str] = mapped_column(String(3))
    description_raw: Mapped[str] = mapped_column(String)
    description_clean: Mapped[str] = mapped_column(String)
    merchant: Mapped[str | None] = mapped_column(String(255), nullable=True)
    category_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("categories.id"), nullable=True, index=True
    )
    categorization_source: Mapped[str] = mapped_column(String(20))
    categorization_confidence: Mapped[float | None] = mapped_column(Float, nullable=True)
    needs_review: Mapped[bool] = mapped_column(Boolean, default=True)
    fitid: Mapped[str | None] = mapped_column(String(255), nullable=True)
    dedup_hash: Mapped[str] = mapped_column(String(64))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )
