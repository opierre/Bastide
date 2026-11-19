"""SQLAlchemy models for placements: investments followed from the values the user declares.

A placement (PEA, assurance vie, PEE…) is not an account: nothing is imported into it and it
has no transactions. The user records the money paid in or taken out, and copies its value from
a statement. Every figure derived from these rows — net payments, unrealised gain, age — is
computed on read and never stored (`docs/design/17-placements.md`).
"""

from datetime import UTC, date, datetime
from uuid import uuid4

from sqlalchemy import Date, ForeignKey, Index, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, UtcDateTime


class Investment(Base):
    """One investment envelope the user follows by hand."""

    __tablename__ = "investments"
    __table_args__ = (Index("ix_investments_user_id", "user_id"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"))
    name: Mapped[str] = mapped_column(String(255))
    institution: Mapped[str] = mapped_column(String(255))
    #: A key of the envelope catalogue (`schemas.Envelope`); labelled by the frontend.
    envelope: Mapped[str] = mapped_column(String(30))
    opened_on: Mapped[date] = mapped_column(Date)
    #: Set when the user closes the placement: it leaves net worth from that date, stays listed.
    closed_on: Mapped[date | None] = mapped_column(Date, nullable=True)
    #: The user's currency, per the one-currency rule; kept for a future multi-currency.
    currency: Mapped[str] = mapped_column(String(3))
    created_at: Mapped[datetime] = mapped_column(UtcDateTime(), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        UtcDateTime(),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )


class InvestmentMovement(Base):
    """Money paid into (positive) or taken out of (negative) a placement.

    It may point at the imported transaction that funded it, for the user's reference only:
    the link changes no total, and an account balance is never read or written from here.
    """

    __tablename__ = "investment_movements"
    __table_args__ = (
        Index("ix_investment_movements_investment_occurred", "investment_id", "occurred_on"),
        # One transfer funds one movement: a second link to it would count it twice in the
        # « rapprochés » figure.
        UniqueConstraint("transaction_id", name="uq_investment_movements_transaction_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    #: Cascades: a movement is the placement's own history and means nothing without it.
    investment_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("investments.id", ondelete="CASCADE")
    )
    occurred_on: Mapped[date] = mapped_column(Date)
    #: Signed and never zero: positive = paid in, negative = withdrawn.
    amount_minor: Mapped[int] = mapped_column(Integer)
    currency: Mapped[str] = mapped_column(String(3))
    note: Mapped[str | None] = mapped_column(String(255), nullable=True)
    #: The imported transaction this movement is reconciled with; the link survives neither a
    #: re-import nor the transaction's deletion, which simply clears it.
    transaction_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("transactions.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(UtcDateTime(), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        UtcDateTime(),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )


class InvestmentValuation(Base):
    """A total value the user copied from a statement, as of one date."""

    __tablename__ = "investment_valuations"
    __table_args__ = (
        # One declared value per day: two would make "the value on that date" ambiguous.
        UniqueConstraint("investment_id", "valued_on"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    investment_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("investments.id", ondelete="CASCADE")
    )
    valued_on: Mapped[date] = mapped_column(Date)
    #: Zero or positive: the total the statement shows.
    value_minor: Mapped[int] = mapped_column(Integer)
    currency: Mapped[str] = mapped_column(String(3))
    note: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime(), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        UtcDateTime(),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )
