"""SQLAlchemy models for accounts and their monthly balance snapshots."""

from datetime import UTC, date, datetime
from uuid import uuid4

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Account(Base):
    """A user's bank/cash account. Balance is cached and derived from the ledger."""

    __tablename__ = "accounts"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(255))
    type: Mapped[str] = mapped_column(String(20))
    institution: Mapped[str] = mapped_column(String(255))
    currency: Mapped[str] = mapped_column(String(3))
    ofx_account_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    opening_balance_minor: Mapped[int] = mapped_column(Integer)
    archived: Mapped[bool] = mapped_column(Boolean, default=False)
    cached_balance_minor: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )


class AccountBalanceSnapshot(Base):
    """A point-in-time account balance, bounding historical balance queries."""

    __tablename__ = "account_balance_snapshots"
    __table_args__ = (UniqueConstraint("account_id", "period_end"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    account_id: Mapped[str] = mapped_column(String(36), ForeignKey("accounts.id"), index=True)
    period_end: Mapped[date] = mapped_column(Date)
    balance_minor: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
