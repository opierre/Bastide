"""SQLAlchemy models for users and their session tokens."""

from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import ForeignKey, LargeBinary, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, UtcDateTime

AVATAR_MONOGRAM = "monogram"
AVATAR_IMAGE = "image"
AVATAR_PRESET_PREFIX = "preset:"


class User(Base):
    """A registered user; owns all accounts, transactions, and rules."""

    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    # Null for users created before recovery codes existed, until they generate one.
    recovery_code_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    # Doubles as the username: unique, stored lowercased (see `schemas.DisplayName`).
    display_name: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    locale: Mapped[str] = mapped_column(String(5))
    currency: Mapped[str] = mapped_column(String(3))
    # `monogram`, `preset:<key>` (see `schemas.AVATAR_PRESETS`) or `image` (a `UserAvatar` row).
    avatar: Mapped[str] = mapped_column(String(40), default=AVATAR_MONOGRAM)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime(), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        UtcDateTime(),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )


class UserAvatar(Base):
    """The picture a user uploaded as their avatar, already re-encoded as a 256×256 PNG.

    Part of the profile, like the display name: neither a backup nor a database reset
    touches it (`app.core.user_data`).
    """

    __tablename__ = "user_avatars"

    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), primary_key=True)
    image: Mapped[bytes] = mapped_column(LargeBinary())
    content_type: Mapped[str] = mapped_column(String(50))
    # The default in effect before the upload, which removing the picture brings back.
    previous_choice: Mapped[str] = mapped_column(String(40))
    updated_at: Mapped[datetime] = mapped_column(UtcDateTime())


class AuthToken(Base):
    """An opaque bearer session token issued at login; deleted on logout."""

    __tablename__ = "auth_tokens"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), index=True)
    token: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime(), default=lambda: datetime.now(UTC))
