"""SQLAlchemy models for savings goals and their allocations (virtual envelopes)."""

from datetime import UTC, date, datetime
from uuid import uuid4

from sqlalchemy import Date, DateTime, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Goal(Base):
    """A savings target the user allocates money toward on paper.

    Purely virtual: a goal is not linked to an account, writes no transactions, and moves no
    balance (PROJECT.md §13).
    """

    __tablename__ = "goals"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(255))
    #: Positive: a target is an amount to reach, never an outflow.
    target_minor: Mapped[int] = mapped_column(Integer)
    currency: Mapped[str] = mapped_column(String(3))
    target_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    icon: Mapped[str] = mapped_column(String(50))
    color: Mapped[str] = mapped_column(String(20))
    status: Mapped[str] = mapped_column(String(10))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )


class GoalAllocation(Base):
    """One append-only movement into (or back out of) a goal's envelope.

    ``amount_minor`` is signed: negative = taking money back out, which keeps the history
    append-only rather than mutable.
    """

    __tablename__ = "goal_allocations"
    __table_args__ = (Index("ix_goal_allocations_goal_id", "goal_id"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    #: Cascades: allocations are the goal's own history and have no meaning without it.
    goal_id: Mapped[str] = mapped_column(String(36), ForeignKey("goals.id", ondelete="CASCADE"))
    amount_minor: Mapped[int] = mapped_column(Integer)
    allocated_on: Mapped[date] = mapped_column(Date)
    note: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
