"""add account settlement account

Revision ID: a1d4c7e9f203
Revises: 3e7a1c9d5b24
Create Date: 2026-10-30 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a1d4c7e9f203"
down_revision: str | Sequence[str] | None = "3e7a1c9d5b24"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Record, on a deferred-debit card, the account its monthly debit is drawn from.

    Nullable: cards opened before this have none until the user picks it. `SET NULL` rather
    than cascading: losing the settlement account must not take the card with it.
    """
    with op.batch_alter_table("accounts", schema=None) as batch_op:
        batch_op.add_column(sa.Column("settlement_account_id", sa.String(length=36), nullable=True))
        batch_op.create_foreign_key(
            "fk_accounts_settlement_account_id",
            "accounts",
            ["settlement_account_id"],
            ["id"],
            ondelete="SET NULL",
        )


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("accounts", schema=None) as batch_op:
        batch_op.drop_constraint("fk_accounts_settlement_account_id", type_="foreignkey")
        batch_op.drop_column("settlement_account_id")
