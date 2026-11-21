"""add savings rate goal

Revision ID: f4b8e2d6a173
Revises: a8d3f1c6e924
Create Date: 2026-11-21 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f4b8e2d6a173"
down_revision: str | Sequence[str] | None = "a8d3f1c6e924"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Store the dashboard's savings-rate goal per user, in whole percent (default 20)."""
    with op.batch_alter_table("user_settings") as batch_op:
        batch_op.add_column(
            sa.Column(
                "savings_rate_goal_percent",
                sa.Integer(),
                nullable=False,
                server_default="20",
            )
        )


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table("user_settings") as batch_op:
        batch_op.drop_column("savings_rate_goal_percent")
