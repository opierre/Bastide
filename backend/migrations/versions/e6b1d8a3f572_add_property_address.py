"""add property address

Revision ID: e6b1d8a3f572
Revises: a7d4c2e9f1b6
Create Date: 2026-11-01 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e6b1d8a3f572"
down_revision: str | Sequence[str] | None = "a7d4c2e9f1b6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Give properties an optional free-text address.

    Nullable with no backfill: properties declared before this migration simply have none.
    """
    with op.batch_alter_table("properties", schema=None) as batch_op:
        batch_op.add_column(sa.Column("address", sa.String(length=255), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("properties", schema=None) as batch_op:
        batch_op.drop_column("address")
