"""add recurring series archived

Revision ID: e5b9c3a7d214
Revises: a7d4c2e9f1b6
Create Date: 2026-11-01 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e5b9c3a7d214"
down_revision: str | Sequence[str] | None = "a7d4c2e9f1b6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Let the user archive a recurring series: every existing one starts live."""
    with op.batch_alter_table("recurring_series") as batch_op:
        batch_op.add_column(
            sa.Column("archived", sa.Boolean(), nullable=False, server_default=sa.false())
        )


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("recurring_series") as batch_op:
        batch_op.drop_column("archived")
