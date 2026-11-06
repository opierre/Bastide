"""add user avatar

Revision ID: f2c8a4e6b913
Revises: e04266cc2e79
Create Date: 2026-11-06 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f2c8a4e6b913"
down_revision: str | Sequence[str] | None = "e04266cc2e79"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Let the user choose an avatar: a preset, or a picture of their own.

    Every existing user keeps the initials monogram they were shown until now.
    """
    with op.batch_alter_table("users") as batch_op:
        batch_op.add_column(
            sa.Column("avatar", sa.String(length=40), nullable=False, server_default="monogram")
        )

    op.create_table(
        "user_avatars",
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("image", sa.LargeBinary(), nullable=False),
        sa.Column("content_type", sa.String(length=50), nullable=False),
        sa.Column("previous_choice", sa.String(length=40), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("user_id"),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table("user_avatars")
    with op.batch_alter_table("users") as batch_op:
        batch_op.drop_column("avatar")
