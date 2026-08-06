"""add unique account ofx account id

Revision ID: b1c7a4e9d820
Revises: 662ad14df059
Create Date: 2026-08-06 10:12:44.118392

"""

from collections.abc import Sequence

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b1c7a4e9d820"
down_revision: str | Sequence[str] | None = "662ad14df059"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_CONSTRAINT = "uq_accounts_user_ofx_account_id"


def upgrade() -> None:
    """Make an account's bank account id unique per user where it is set.

    The column already exists and stays nullable: accounts opened by hand carry
    no id. NULLs are distinct under both SQLite and Postgres, so only accounts
    that actually declare an id are constrained.
    """
    with op.batch_alter_table("accounts", schema=None) as batch_op:
        batch_op.create_unique_constraint(_CONSTRAINT, ["user_id", "ofx_account_id"])


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("accounts", schema=None) as batch_op:
        batch_op.drop_constraint(_CONSTRAINT, type_="unique")
