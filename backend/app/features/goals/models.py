"""SQLAlchemy models for savings goals and their allocations (virtual envelopes)."""

from datetime import UTC, date, datetime
from uuid import uuid4

from sqlalchemy import Date, ForeignKey, Index, Integer, LargeBinary, String
from sqlalchemy.orm import Mapped, deferred, mapped_column, relationship

from app.core.db import Base, UtcDateTime


class Goal(Base):
    """A savings target the user allocates money toward on paper.

    Purely virtual: a goal is not linked to an account, writes no transactions, and moves no
    balance.
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
    created_at: Mapped[datetime] = mapped_column(UtcDateTime(), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        UtcDateTime(),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )
    # Loaded with the goal (without its pixels), so whether a goal has a banner never costs a
    # query per goal. A goal is only ever archived, but were one deleted its image would go too.
    image: Mapped[GoalImage | None] = relationship(
        lazy="selectin", cascade="all, delete-orphan", passive_deletes=True
    )


class GoalImage(Base):
    """The banner picture a user gave a goal, already re-encoded as a 44:19 PNG.

    User data, like the goal itself: backups carry it and a reset deletes it.
    """

    __tablename__ = "goal_images"

    goal_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("goals.id", ondelete="CASCADE", name="fk_goal_images_goal_id"),
        primary_key=True,
    )
    # Deferred: listing goals needs to know a banner exists and when it changed, not its bytes.
    image: Mapped[bytes] = deferred(mapped_column(LargeBinary()))
    content_type: Mapped[str] = mapped_column(String(50))
    updated_at: Mapped[datetime] = mapped_column(UtcDateTime())


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
    created_at: Mapped[datetime] = mapped_column(UtcDateTime(), default=lambda: datetime.now(UTC))
