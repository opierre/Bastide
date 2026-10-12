"""add user settings update check

Revision ID: b7e4d1a9c352
Revises: f8a2d5c3e910
Create Date: 2026-10-11 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b7e4d1a9c352"
down_revision: str | Sequence[str] | None = "f8a2d5c3e910"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add the opt-in update check: off for every existing user, nothing checked yet."""
    with op.batch_alter_table("user_settings") as batch_op:
        batch_op.add_column(
            sa.Column(
                "update_check_enabled", sa.Boolean(), nullable=False, server_default=sa.false()
            )
        )
        batch_op.add_column(
            sa.Column("update_checked_at", sa.DateTime(timezone=True), nullable=True)
        )
        batch_op.add_column(sa.Column("update_latest_version", sa.String(64), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("user_settings") as batch_op:
        batch_op.drop_column("update_latest_version")
        batch_op.drop_column("update_checked_at")
        batch_op.drop_column("update_check_enabled")
