"""add user settings

Revision ID: e4a1c6f20b73
Revises: d7b2e5c91f38
Create Date: 2026-08-11 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e4a1c6f20b73"
down_revision: str | Sequence[str] | None = "d7b2e5c91f38"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create `user_settings`, one row per user holding the AI configuration.

    No backfill: rows are created lazily on the first `GET /settings`, so existing users
    need no migration-time write and registration stays unchanged.
    """
    op.create_table(
        "user_settings",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("ai_enabled", sa.Boolean(), nullable=False),
        sa.Column("inference_base_url", sa.String(length=255), nullable=False),
        sa.Column("model_tag", sa.String(length=255), nullable=True),
        sa.Column("confidence_threshold", sa.Float(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id"),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table("user_settings")
