"""add user theme

Revision ID: a26ae97e35f1
Revises: 2e098f7e00d6
Create Date: 2026-11-17 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a26ae97e35f1"
down_revision: str | Sequence[str] | None = "2e098f7e00d6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Let the user choose the app's theme: system, dark or light.

    Every existing user keeps the dark theme they were shown until now.
    """
    with op.batch_alter_table("users") as batch_op:
        batch_op.add_column(
            sa.Column("theme", sa.String(length=6), nullable=False, server_default="dark")
        )


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("users") as batch_op:
        batch_op.drop_column("theme")
