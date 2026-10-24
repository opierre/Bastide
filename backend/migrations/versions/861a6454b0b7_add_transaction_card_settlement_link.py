"""add transaction card settlement link

Revision ID: 861a6454b0b7
Revises: b7e4d1a9c352
Create Date: 2026-10-24 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "861a6454b0b7"
down_revision: str | Sequence[str] | None = "b7e4d1a9c352"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Link a deferred-debit card's rows to the current-account debit that settled them.

    Set on every card row a settlement paid, and on the card-side credit that offsets it, so a
    cycle is matched once and the offset can be found again. `SET NULL` rather than cascading:
    deleting the settlement unlinks the cycle, it must not take the purchases with it.
    """
    with op.batch_alter_table("transactions", schema=None) as batch_op:
        batch_op.add_column(sa.Column("card_settlement_id", sa.String(length=36), nullable=True))
        batch_op.create_index(
            batch_op.f("ix_transactions_card_settlement_id"), ["card_settlement_id"], unique=False
        )
        batch_op.create_foreign_key(
            "fk_transactions_card_settlement_id",
            "transactions",
            ["card_settlement_id"],
            ["id"],
            ondelete="SET NULL",
        )


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("transactions", schema=None) as batch_op:
        batch_op.drop_constraint("fk_transactions_card_settlement_id", type_="foreignkey")
        batch_op.drop_index(batch_op.f("ix_transactions_card_settlement_id"))
        batch_op.drop_column("card_settlement_id")
