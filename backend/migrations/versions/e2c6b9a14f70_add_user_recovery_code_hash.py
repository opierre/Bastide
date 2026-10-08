"""add user recovery code hash

Revision ID: e2c6b9a14f70
Revises: c7e2a9d4b150
Create Date: 2026-10-08 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e2c6b9a14f70"
down_revision: str | Sequence[str] | None = "c7e2a9d4b150"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add `users.recovery_code_hash`, null for existing users until they generate a code."""
    with op.batch_alter_table("users") as batch_op:
        batch_op.add_column(sa.Column("recovery_code_hash", sa.String(255), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("users") as batch_op:
        batch_op.drop_column("recovery_code_hash")
