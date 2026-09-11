"""SQLAlchemy model for categorization runs (Phase 2: the AI categorisation pass)."""

from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class CategorizationRun(Base):
    """One AI categorisation pass over a user's transactions.

    Persisted rather than in-memory so a run's outcome survives a sidecar restart and the
    history stays inspectable — the same reasoning as ``import_batches``.
    """

    __tablename__ = "categorization_runs"
    # The history query lists a user's runs newest-first; the composite index covers it.
    __table_args__ = (Index("ix_categorization_runs_user_created_at", "user_id", "created_at"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"))
    #: NULL = the run covered every account.
    account_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("accounts.id"), nullable=True
    )
    #: Set when the run was triggered by an import rather than by the user.
    import_batch_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("import_batches.id"), nullable=True
    )
    trigger: Mapped[str] = mapped_column(String(10))
    status: Mapped[str] = mapped_column(String(10))
    #: The model actually used, recorded for auditability.
    model_tag: Mapped[str | None] = mapped_column(String(255), nullable=True)
    total_count: Mapped[int] = mapped_column(Integer, default=0)
    processed_count: Mapped[int] = mapped_column(Integer, default=0)
    assigned_count: Mapped[int] = mapped_column(Integer, default=0)
    deferred_count: Mapped[int] = mapped_column(Integer, default=0)
    failed_count: Mapped[int] = mapped_column(Integer, default=0)
    error_message: Mapped[str | None] = mapped_column(String, nullable=True)
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )
