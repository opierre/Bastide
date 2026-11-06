"""add rule logos

Revision ID: a7d3e1c95b20
Revises: f2c8a4e6b913
Create Date: 2026-11-06 12:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a7d3e1c95b20"
down_revision: str | Sequence[str] | None = "f2c8a4e6b913"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Let a categorization rule carry a logo the user uploaded, one per rule."""
    op.create_table(
        "rule_logos",
        sa.Column("rule_id", sa.String(length=36), nullable=False),
        sa.Column("image", sa.LargeBinary(), nullable=False),
        sa.Column("content_type", sa.String(length=50), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["rule_id"],
            ["categorization_rules.id"],
            name="fk_rule_logos_rule_id",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("rule_id"),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table("rule_logos")
