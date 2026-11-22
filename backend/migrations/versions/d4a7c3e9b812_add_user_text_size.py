"""add user text size

Revision ID: d4a7c3e9b812
Revises: c8e2f5a1d937
Create Date: 2026-11-23 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "d4a7c3e9b812"
down_revision: str | Sequence[str] | None = "c8e2f5a1d937"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Let the user choose the app's text size: normal, large or extra large.

    A plain ADD COLUMN, not a batch: rebuilding ``users`` in batch mode would drop the
    ``lower(display_name)`` expression index, which SQLite reflection can't copy.
    """
    op.add_column(
        "users",
        sa.Column("text_size", sa.String(length=6), nullable=False, server_default="normal"),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("users", "text_size")
