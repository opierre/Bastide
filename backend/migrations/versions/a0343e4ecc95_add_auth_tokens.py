"""add auth tokens

Revision ID: a0343e4ecc95
Revises: 24ef282f7623
Create Date: 2026-07-19 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a0343e4ecc95"
down_revision: str | Sequence[str] | None = "24ef282f7623"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "auth_tokens",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("token", sa.String(length=64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("auth_tokens", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_auth_tokens_user_id"), ["user_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_auth_tokens_token"), ["token"], unique=True)


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("auth_tokens", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_auth_tokens_token"))
        batch_op.drop_index(batch_op.f("ix_auth_tokens_user_id"))

    op.drop_table("auth_tokens")
