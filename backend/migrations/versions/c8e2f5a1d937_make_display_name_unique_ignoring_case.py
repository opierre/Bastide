"""make the display name unique regardless of case

Revision ID: c8e2f5a1d937
Revises: b7d2e9a4c615
Create Date: 2026-11-22 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c8e2f5a1d937"
down_revision: str | Sequence[str] | None = "b7d2e9a4c615"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Keep the display name's case, and make it unique on its lowercased form.

    An expression index, which SQLite and PostgreSQL both support, so « Camille Dubois » and
    « camille dubois » can't be two accounts.
    """
    op.drop_index("ix_users_display_name", table_name="users")
    op.create_index(
        "ix_users_display_name_lower",
        "users",
        [sa.text("lower(display_name)")],
        unique=True,
    )


def downgrade() -> None:
    """Go back to a unique index on the display name as stored."""
    op.drop_index("ix_users_display_name_lower", table_name="users")
    op.create_index("ix_users_display_name", "users", ["display_name"], unique=True)
