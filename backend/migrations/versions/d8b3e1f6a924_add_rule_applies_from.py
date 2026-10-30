"""add rule applies from

Revision ID: d8b3e1f6a924
Revises: c5a9d2f7e381
Create Date: 2026-10-30 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "d8b3e1f6a924"
down_revision: str | Sequence[str] | None = "c5a9d2f7e381"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Let a rule start at a date: it matches no transaction booked before it.

    Set on a deferred card's settlement rule, so the debits paying purchases from before the
    card's imported history stay spending — they are the only record of it.
    """
    with op.batch_alter_table("categorization_rules", schema=None) as batch_op:
        batch_op.add_column(sa.Column("applies_from", sa.Date(), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("categorization_rules", schema=None) as batch_op:
        batch_op.drop_column("applies_from")
