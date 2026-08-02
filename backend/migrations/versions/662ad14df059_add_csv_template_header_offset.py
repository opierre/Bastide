"""add csv template header offset

Revision ID: 662ad14df059
Revises: a0343e4ecc95
Create Date: 2026-08-02 13:52:18.303287

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "662ad14df059"
down_revision: str | Sequence[str] | None = "a0343e4ecc95"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    with op.batch_alter_table("csv_templates", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column("header_offset", sa.Integer(), nullable=False, server_default="0")
        )


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("csv_templates", schema=None) as batch_op:
        batch_op.drop_column("header_offset")
