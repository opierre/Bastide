"""add goal images

Revision ID: e6a2c9d4b718
Revises: 5b8d1f3a6c27
Create Date: 2026-11-20 12:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e6a2c9d4b718"
down_revision: str | Sequence[str] | None = "5b8d1f3a6c27"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Let a goal carry a banner picture the user uploaded, one per goal."""
    op.create_table(
        "goal_images",
        sa.Column("goal_id", sa.String(length=36), nullable=False),
        sa.Column("image", sa.LargeBinary(), nullable=False),
        sa.Column("content_type", sa.String(length=50), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["goal_id"],
            ["goals.id"],
            name="fk_goal_images_goal_id",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("goal_id"),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table("goal_images")
