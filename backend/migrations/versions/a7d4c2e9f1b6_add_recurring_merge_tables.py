"""add recurring merge tables

Revision ID: a7d4c2e9f1b6
Revises: d8b3e1f6a924
Create Date: 2026-10-31 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a7d4c2e9f1b6"
down_revision: str | Sequence[str] | None = "d8b3e1f6a924"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create the tables behind merging two recurring series into one.

    `recurring_merchant_aliases` maps a merged-away grouping key to the series that absorbed
    it, so detection groups both labels together; `recurring_merge_dismissals` remembers the
    pairs the user said are distinct, so they are never proposed again.
    """
    op.create_table(
        "recurring_merchant_aliases",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("account_id", sa.String(length=36), nullable=False),
        sa.Column("series_id", sa.String(length=36), nullable=False),
        sa.Column("merchant_key", sa.String(length=255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["account_id"], ["accounts.id"]),
        sa.ForeignKeyConstraint(["series_id"], ["recurring_series.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "account_id", "merchant_key", name="uq_recurring_alias_account_merchant"
        ),
    )
    with op.batch_alter_table("recurring_merchant_aliases", schema=None) as batch_op:
        batch_op.create_index(
            "ix_recurring_merchant_aliases_series_id", ["series_id"], unique=False
        )
    op.create_table(
        "recurring_merge_dismissals",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("account_id", sa.String(length=36), nullable=False),
        sa.Column("first_key", sa.String(length=255), nullable=False),
        sa.Column("second_key", sa.String(length=255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["account_id"], ["accounts.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "account_id", "first_key", "second_key", name="uq_recurring_merge_dismissal_pair"
        ),
    )


def downgrade() -> None:
    """Drop both tables; the series a merge kept stay as they are."""
    op.drop_table("recurring_merge_dismissals")
    with op.batch_alter_table("recurring_merchant_aliases", schema=None) as batch_op:
        batch_op.drop_index("ix_recurring_merchant_aliases_series_id")
    op.drop_table("recurring_merchant_aliases")
