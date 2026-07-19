"""SQLAlchemy model for deterministic categorization rules."""

from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class CategorizationRule(Base):
    """A user-defined rule matched against transactions in ascending priority order."""

    __tablename__ = "categorization_rules"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    priority: Mapped[int] = mapped_column(Integer)
    match_field: Mapped[str] = mapped_column(String(20))
    match_type: Mapped[str] = mapped_column(String(10))
    pattern: Mapped[str] = mapped_column(String(255))
    category_id: Mapped[str] = mapped_column(String(36), ForeignKey("categories.id"))
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
