"""add import batch balance mismatch

Revision ID: a83dd88e80a1
Revises: b1c7a4e9d820
Create Date: 2026-08-07 00:14:29.591771

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a83dd88e80a1"
down_revision: str | Sequence[str] | None = "b1c7a4e9d820"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Record the gap when a statement's declared balance disagrees with the ledger.

    Both columns are nullable and only ever set from an account's second import
    onward — its first derives the opening balance from the same figure instead
    of comparing against it.
    """
    with op.batch_alter_table("import_batches", schema=None) as batch_op:
        batch_op.add_column(sa.Column("balance_mismatch_minor", sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column("balance_mismatch_as_of", sa.Date(), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("import_batches", schema=None) as batch_op:
        batch_op.drop_column("balance_mismatch_as_of")
        batch_op.drop_column("balance_mismatch_minor")
