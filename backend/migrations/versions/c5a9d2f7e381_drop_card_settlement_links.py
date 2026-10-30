"""drop card settlement links

Revision ID: c5a9d2f7e381
Revises: b3f6e8a1c5d7
Create Date: 2026-10-30 00:00:00.000000

"""

import hashlib
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c5a9d2f7e381"
down_revision: str | Sequence[str] | None = "b3f6e8a1c5d7"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _offset_hash(settlement_id: str) -> str:
    """The dedup hash the removed settlement code gave the card credit it posted."""
    return hashlib.sha256(f"card-settlement:{settlement_id}".encode()).hexdigest()


def upgrade() -> None:
    """Retire the matching of a card's settlement to its purchases.

    A card's monthly debit is now filed as a transfer by the card's own rule, and nothing ties
    it to the purchases it paid. What the matching left behind goes with it:

    - The credits it posted on cards to close a cycle are deleted. Their amount moves into the
      card's opening balance so its cached balance — and the snapshots, which are absolute —
      still read what they read before; a card counts in no total any more, so this only keeps
      its own figure where the bank put it.
    - Settlements proposed by their label and never confirmed go back to the review queue
      uncategorised: no rule of the user's filed them, and the card's rule will once saved.
    - The link column is dropped.
    """
    bind = op.get_bind()
    linked = bind.execute(
        sa.text(
            "SELECT id, account_id, amount_minor, dedup_hash, card_settlement_id "
            "FROM transactions WHERE card_settlement_id IS NOT NULL"
        )
    ).all()
    for row_id, account_id, amount_minor, dedup_hash, settlement_id in linked:
        if dedup_hash != _offset_hash(settlement_id):
            continue
        bind.execute(sa.text("DELETE FROM transactions WHERE id = :id"), {"id": row_id})
        bind.execute(
            sa.text(
                "UPDATE accounts SET opening_balance_minor = opening_balance_minor + :amount "
                "WHERE id = :account_id"
            ),
            {"amount": amount_minor, "account_id": account_id},
        )
    bind.execute(
        sa.text(
            "UPDATE transactions SET category_id = NULL, "
            "categorization_source = 'uncategorized', needs_review = :review "
            "WHERE categorization_source = 'detected'"
        ),
        {"review": True},
    )

    with op.batch_alter_table("transactions", schema=None) as batch_op:
        batch_op.drop_constraint("fk_transactions_card_settlement_id", type_="foreignkey")
        batch_op.drop_index(batch_op.f("ix_transactions_card_settlement_id"))
        batch_op.drop_column("card_settlement_id")


def downgrade() -> None:
    """Restore the link column, empty: the matching it recorded is not rebuilt."""
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
