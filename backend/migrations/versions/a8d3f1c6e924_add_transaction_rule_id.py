"""add transaction rule id

Revision ID: a8d3f1c6e924
Revises: e6a2c9d4b718
Create Date: 2026-11-21 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a8d3f1c6e924"
down_revision: str | Sequence[str] | None = "e6a2c9d4b718"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Record on each transaction the rule that classed it."""
    with op.batch_alter_table("transactions", schema=None) as batch_op:
        batch_op.add_column(sa.Column("rule_id", sa.String(length=36), nullable=True))
        batch_op.create_index(batch_op.f("ix_transactions_rule_id"), ["rule_id"], unique=False)
        batch_op.create_foreign_key(
            "fk_transactions_rule_id",
            "categorization_rules",
            ["rule_id"],
            ["id"],
            ondelete="SET NULL",
        )


def downgrade() -> None:
    """Drop the attribution; the categories it explained stay."""
    with op.batch_alter_table("transactions", schema=None) as batch_op:
        batch_op.drop_constraint("fk_transactions_rule_id", type_="foreignkey")
        batch_op.drop_index(batch_op.f("ix_transactions_rule_id"))
        batch_op.drop_column("rule_id")
