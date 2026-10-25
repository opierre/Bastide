"""SQLAlchemy model for the month-end totals a user declares for the time before their imports."""

from datetime import UTC, date, datetime
from uuid import uuid4

from sqlalchemy import Date, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class DeclaredBalance(Base):
    """What the user says all their accounts held together at one month end.

    Typed in, never derived: history from before the first statement, which no import can
    supply. Kept apart from `account_balance_snapshots` on purpose — a snapshot is a cache of
    the ledger that imports and opening-balance edits shift, and it is per account, whereas
    this is one total the user wrote down. The net-worth series reads it only for a month
    the ledger has no snapshot for.
    """

    __tablename__ = "declared_balances"
    __table_args__ = (UniqueConstraint("user_id", "period_end"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    #: The last day of the month the total was recorded for.
    period_end: Mapped[date] = mapped_column(Date)
    #: Signed: an overdrawn total is negative.
    amount_minor: Mapped[int] = mapped_column(Integer)
    currency: Mapped[str] = mapped_column(String(3))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )
