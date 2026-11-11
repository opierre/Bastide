"""SQLAlchemy models for deterministic categorization rules and the logos users give them."""

from datetime import UTC, date, datetime
from uuid import uuid4

from sqlalchemy import (
    Boolean,
    Date,
    ForeignKey,
    Integer,
    LargeBinary,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, deferred, mapped_column, relationship

from app.core.db import Base, UtcDateTime


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
    # No transaction booked before this date matches the rule; `None` for no limit. Set on a
    # deferred card's settlement rule, whose debits before the card's history pay purchases the
    # ledger doesn't hold.
    applies_from: Mapped[date | None] = mapped_column(Date, nullable=True)
    # Set on the one rule that files a deferred card's monthly debit: the card it settles. The
    # rule itself is ordinary — this only says whose it is.
    settlement_card_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey(
            "accounts.id", ondelete="SET NULL", name="fk_categorization_rules_settlement_card_id"
        ),
        nullable=True,
        unique=True,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(UtcDateTime(), default=lambda: datetime.now(UTC))
    # Loaded with the rule (without its pixels), so whether a rule has a logo never costs a
    # query per rule. Deleting the rule deletes its logo.
    logo: Mapped[RuleLogo | None] = relationship(
        lazy="selectin", cascade="all, delete-orphan", passive_deletes=True
    )


class RuleLogo(Base):
    """The picture a user gave a rule, already re-encoded as a square PNG.

    Shown on the merchant chip of the transactions and series the rule matches, in place of
    the monogram. User data, unlike the avatar: backups carry it and a reset deletes it.
    """

    __tablename__ = "rule_logos"

    rule_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("categorization_rules.id", ondelete="CASCADE", name="fk_rule_logos_rule_id"),
        primary_key=True,
    )
    # Deferred: listing rules needs to know a logo exists and when it changed, not its bytes.
    image: Mapped[bytes] = deferred(mapped_column(LargeBinary()))
    content_type: Mapped[str] = mapped_column(String(50))
    updated_at: Mapped[datetime] = mapped_column(UtcDateTime())


class RulePackImport(Base):
    """A built-in rule pack the user has imported, so the app stops offering it.

    Keyed by the bundled pack's id (its file stem), one row per user and pack: importing the
    same pack again keeps the first row. Not touched when the user later deletes the pack's
    rules — the user imported it and can do so again from a file.
    """

    __tablename__ = "rule_pack_imports"
    __table_args__ = (UniqueConstraint("user_id", "builtin_id"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    builtin_id: Mapped[str] = mapped_column(String(100))
    imported_at: Mapped[datetime] = mapped_column(UtcDateTime(), default=lambda: datetime.now(UTC))
