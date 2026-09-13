"""SQLAlchemy model for declared real-estate properties (Phase 3)."""

from datetime import UTC, date, datetime
from uuid import uuid4

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Property(Base):
    """A property the user declares: the app never sees one in a bank statement.

    One entity rather than a figure duplicated per panel: net worth (§18) reads it.
    """

    __tablename__ = "properties"
    __table_args__ = (
        # The Synthèse panel lists a user's properties, archived ones hidden.
        Index("ix_properties_user_archived", "user_id", "archived"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"))
    label: Mapped[str] = mapped_column(String(255))
    kind: Mapped[str] = mapped_column(String(20))
    #: Declared current value, positive.
    market_value_minor: Mapped[int] = mapped_column(Integer)
    #: When that value was declared — an estimate ages, and the UI says so.
    valued_on: Mapped[date] = mapped_column(Date)
    #: The user's share in basis points; 10000 = 100 % (indivision/SCI quote-part).
    ownership_bps: Mapped[int] = mapped_column(Integer, default=10000)
    acquisition_price_minor: Mapped[int | None] = mapped_column(Integer, nullable=True)
    acquired_on: Mapped[date | None] = mapped_column(Date, nullable=True)
    archived: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )
