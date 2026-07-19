"""SQLAlchemy model for categories (system defaults + user-defined)."""

from uuid import uuid4

from sqlalchemy import Boolean, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Category(Base):
    """A transaction category. System categories have ``user_id = None``."""

    __tablename__ = "categories"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("users.id"), nullable=True, index=True
    )
    parent_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("categories.id"), nullable=True, index=True
    )
    name: Mapped[str] = mapped_column(String(255))
    kind: Mapped[str] = mapped_column(String(10))
    icon: Mapped[str] = mapped_column(String(50))
    color: Mapped[str] = mapped_column(String(7))
    is_system: Mapped[bool] = mapped_column(Boolean, default=False)
