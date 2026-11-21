"""add transaction excluded_from_totals

Revision ID: a7d3e9f2c418
Revises: e6a2c9d4b718
Create Date: 2026-11-21 12:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a7d3e9f2c418"
down_revision: str | Sequence[str] | None = "e6a2c9d4b718"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Let the user keep a transaction out of the totals; every existing row counts."""
    op.add_column(
        "transactions",
        sa.Column(
            "excluded_from_totals",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )


def downgrade() -> None:
    """Drop the flag; every row counts again."""
    with op.batch_alter_table("transactions") as batch_op:
        batch_op.drop_column("excluded_from_totals")
