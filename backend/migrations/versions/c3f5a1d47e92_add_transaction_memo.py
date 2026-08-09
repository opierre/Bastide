"""add transaction memo

Revision ID: c3f5a1d47e92
Revises: a83dd88e80a1
Create Date: 2026-08-09 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c3f5a1d47e92"
down_revision: str | Sequence[str] | None = "a83dd88e80a1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Give transactions their own column for the bank's free-text detail (OFX `MEMO`).

    Nullable: CSV imports carry no memo, and rows imported before this migration keep
    theirs folded into `description_raw` — backfilling would mean re-parsing files the
    database no longer holds, so old rows simply show no memo line.
    """
    with op.batch_alter_table("transactions", schema=None) as batch_op:
        batch_op.add_column(sa.Column("memo", sa.String(), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("transactions", schema=None) as batch_op:
        batch_op.drop_column("memo")
