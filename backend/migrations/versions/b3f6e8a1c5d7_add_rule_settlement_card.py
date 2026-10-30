"""add rule settlement card

Revision ID: b3f6e8a1c5d7
Revises: a1d4c7e9f203
Create Date: 2026-10-30 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b3f6e8a1c5d7"
down_revision: str | Sequence[str] | None = "a1d4c7e9f203"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Mark the rule that files a deferred card's monthly debit as that card's.

    On the rule rather than the card, because rules are restored after accounts. Unique: a card
    has one such rule. `SET NULL`: an account is only ever archived, but if one goes, its rule
    stays an ordinary rule.
    """
    with op.batch_alter_table("categorization_rules", schema=None) as batch_op:
        batch_op.add_column(sa.Column("settlement_card_id", sa.String(length=36), nullable=True))
        batch_op.create_index(
            batch_op.f("ix_categorization_rules_settlement_card_id"),
            ["settlement_card_id"],
            unique=True,
        )
        batch_op.create_foreign_key(
            "fk_categorization_rules_settlement_card_id",
            "accounts",
            ["settlement_card_id"],
            ["id"],
            ondelete="SET NULL",
        )


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("categorization_rules", schema=None) as batch_op:
        batch_op.drop_constraint("fk_categorization_rules_settlement_card_id", type_="foreignkey")
        batch_op.drop_index(batch_op.f("ix_categorization_rules_settlement_card_id"))
        batch_op.drop_column("settlement_card_id")
