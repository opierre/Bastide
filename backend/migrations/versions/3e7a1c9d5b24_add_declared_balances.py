"""add declared balances

Revision ID: 3e7a1c9d5b24
Revises: 861a6454b0b7
Create Date: 2026-10-25 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "3e7a1c9d5b24"
down_revision: str | Sequence[str] | None = "861a6454b0b7"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Store the month-end totals a user declares for the months before their first import.

    One row per user and month: the net-worth series reads it for a month the ledger has no
    snapshot for, so two figures for the same month would be ambiguous.
    """
    op.create_table(
        "declared_balances",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("period_end", sa.Date(), nullable=False),
        sa.Column("amount_minor", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "period_end"),
    )
    with op.batch_alter_table("declared_balances", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_declared_balances_user_id"), ["user_id"], unique=False)


def downgrade() -> None:
    """Drop the declared balances; the figures the user typed are not recoverable."""
    with op.batch_alter_table("declared_balances", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_declared_balances_user_id"))
    op.drop_table("declared_balances")
