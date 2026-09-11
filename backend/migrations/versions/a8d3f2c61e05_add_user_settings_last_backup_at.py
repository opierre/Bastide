"""add user settings last backup at

Revision ID: a8d3f2c61e05
Revises: f5c81a930d47
Create Date: 2026-09-11 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a8d3f2c61e05"
down_revision: str | Sequence[str] | None = "f5c81a930d47"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add `user_settings.last_backup_at`, null until the user's first export."""
    with op.batch_alter_table("user_settings") as batch_op:
        batch_op.add_column(sa.Column("last_backup_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("user_settings") as batch_op:
        batch_op.drop_column("last_backup_at")
