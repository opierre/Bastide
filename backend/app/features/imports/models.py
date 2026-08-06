"""SQLAlchemy models for import batches and per-bank CSV templates."""

from datetime import UTC, date, datetime
from uuid import uuid4

from sqlalchemy import JSON, Date, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class ImportBatch(Base):
    """One file import attempt (OFX/QFX/CSV) into a single account."""

    __tablename__ = "import_batches"
    __table_args__ = (UniqueConstraint("account_id", "file_hash"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    account_id: Mapped[str] = mapped_column(String(36), ForeignKey("accounts.id"), index=True)
    source_format: Mapped[str] = mapped_column(String(10))
    file_name: Mapped[str] = mapped_column(String(255))
    file_hash: Mapped[str] = mapped_column(String(64))
    period_start: Mapped[date] = mapped_column(Date)
    period_end: Mapped[date] = mapped_column(Date)
    transaction_count: Mapped[int] = mapped_column(Integer)
    new_count: Mapped[int] = mapped_column(Integer)
    duplicate_count: Mapped[int] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(10))
    error_message: Mapped[str | None] = mapped_column(String, nullable=True)
    # Set only from an account's *second* statement import onward, and only when the
    # statement's declared balance disagrees with what the ledger implies at its as-of
    # date — see `ImportService._detect_balance_mismatch`. NULL means either there was
    # no declared balance to compare (CSV, or an OFX file without LEDGERBAL) or the two
    # agreed. Never derived from an account's first import: that import derives the
    # opening balance from this same figure instead of comparing against it.
    balance_mismatch_minor: Mapped[int | None] = mapped_column(Integer, nullable=True)
    balance_mismatch_as_of: Mapped[date | None] = mapped_column(Date, nullable=True)
    imported_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )


class CsvTemplate(Base):
    """A saved per-bank CSV column-mapping, reused across imports for that bank."""

    __tablename__ = "csv_templates"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    bank_name: Mapped[str] = mapped_column(String(255))
    delimiter: Mapped[str] = mapped_column(String(1))
    encoding: Mapped[str] = mapped_column(String(20))
    date_format: Mapped[str] = mapped_column(String(20))
    decimal_separator: Mapped[str] = mapped_column(String(1))
    amount_strategy: Mapped[str] = mapped_column(String(20))
    column_map: Mapped[dict] = mapped_column(JSON)
    header_offset: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
