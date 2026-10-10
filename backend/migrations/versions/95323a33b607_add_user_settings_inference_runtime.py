"""add user settings inference runtime

Revision ID: 95323a33b607
Revises: f8a2d5c3e910
Create Date: 2026-10-11 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "95323a33b607"
down_revision: str | Sequence[str] | None = "f8a2d5c3e910"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add `inference_runtime`: the engine at `inference_base_url`, or the downloaded one.

    Existing rows become `external`, which is what they have always meant: the runtime at
    the stored address. The check keeps the column to its two values on Postgres too.
    """
    with op.batch_alter_table("user_settings", schema=None) as batch_op:
        batch_op.add_column(
            sa.Column(
                "inference_runtime",
                sa.String(length=16),
                nullable=False,
                server_default="external",
            )
        )
        batch_op.create_check_constraint(
            "ck_user_settings_inference_runtime",
            "inference_runtime IN ('external', 'managed')",
        )


def downgrade() -> None:
    """Drop `inference_runtime`; every user goes back to the address they stored."""
    with op.batch_alter_table("user_settings", schema=None) as batch_op:
        batch_op.drop_constraint("ck_user_settings_inference_runtime", type_="check")
        batch_op.drop_column("inference_runtime")
