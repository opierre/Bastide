"""SQLAlchemy model for per-user settings (the AI configuration)."""

from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import Boolean, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, UtcDateTime

# Ollama's default port on loopback. `llama-server` uses 8080; either is reachable over the
# same OpenAI-compatible `/v1` surface, which is why the runtime is configuration, not code.
DEFAULT_INFERENCE_BASE_URL = "http://127.0.0.1:11434/v1"
DEFAULT_CONFIDENCE_THRESHOLD = 0.80


class UserSettings(Base):
    """One row per user, created lazily the first time settings are read."""

    __tablename__ = "user_settings"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    # Unique rather than merely indexed: it is what makes lazy creation safe under
    # concurrent first reads — the loser of the race gets an IntegrityError, not a
    # second row.
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), unique=True)
    ai_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    inference_base_url: Mapped[str] = mapped_column(String(255), default=DEFAULT_INFERENCE_BASE_URL)
    model_tag: Mapped[str | None] = mapped_column(String(255), nullable=True)
    confidence_threshold: Mapped[float] = mapped_column(Float, default=DEFAULT_CONFIDENCE_THRESHOLD)
    # When the user last exported a full backup; null until the first one.
    last_backup_at: Mapped[datetime | None] = mapped_column(UtcDateTime(), nullable=True)
    # Monthly income the debt ratio runs on. Null = derive it from the ledger.
    declared_monthly_income_minor: Mapped[int | None] = mapped_column(Integer, nullable=True)
    # Opt-in: off until the user turns it on, because the check is the one request that
    # leaves the machine (to GitHub's release API, see app/features/updates).
    update_check_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    # The last successful check and the newest release it found, so the app asks at most
    # once a day however often it starts.
    update_checked_at: Mapped[datetime | None] = mapped_column(UtcDateTime(), nullable=True)
    update_latest_version: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime(), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        UtcDateTime(),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )
