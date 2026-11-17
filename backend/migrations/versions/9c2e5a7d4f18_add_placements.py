"""add placements

Revision ID: 9c2e5a7d4f18
Revises: c4e9a2f7d618
Create Date: 2026-11-17 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "9c2e5a7d4f18"
down_revision: str | Sequence[str] | None = "c4e9a2f7d618"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Store placements, the money moved in and out of them, and the values the user declares.

    Nothing derived is stored: net payments, gain and age are computed on every read.
    """
    op.create_table(
        "investments",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("institution", sa.String(length=255), nullable=False),
        sa.Column("envelope", sa.String(length=30), nullable=False),
        sa.Column("opened_on", sa.Date(), nullable=False),
        sa.Column("closed_on", sa.Date(), nullable=True),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("investments", schema=None) as batch_op:
        batch_op.create_index("ix_investments_user_id", ["user_id"], unique=False)

    op.create_table(
        "investment_valuations",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("investment_id", sa.String(length=36), nullable=False),
        sa.Column("valued_on", sa.Date(), nullable=False),
        sa.Column("value_minor", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("note", sa.String(length=255), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["investment_id"], ["investments.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("investment_id", "valued_on"),
    )

    op.create_table(
        "investment_movements",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("investment_id", sa.String(length=36), nullable=False),
        sa.Column("occurred_on", sa.Date(), nullable=False),
        sa.Column("amount_minor", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("note", sa.String(length=255), nullable=True),
        sa.Column("transaction_id", sa.String(length=36), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["investment_id"], ["investments.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["transaction_id"], ["transactions.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("transaction_id", name="uq_investment_movements_transaction_id"),
    )
    with op.batch_alter_table("investment_movements", schema=None) as batch_op:
        batch_op.create_index(
            "ix_investment_movements_investment_occurred",
            ["investment_id", "occurred_on"],
            unique=False,
        )


def downgrade() -> None:
    """Drop the placements and their history; the figures the user typed are not recoverable."""
    with op.batch_alter_table("investment_movements", schema=None) as batch_op:
        batch_op.drop_index("ix_investment_movements_investment_occurred")
    op.drop_table("investment_movements")
    op.drop_table("investment_valuations")
    with op.batch_alter_table("investments", schema=None) as batch_op:
        batch_op.drop_index("ix_investments_user_id")
    op.drop_table("investments")
