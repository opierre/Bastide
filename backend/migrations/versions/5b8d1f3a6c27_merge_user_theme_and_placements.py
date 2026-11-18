"""merge the user theme and placements heads

Revision ID: 5b8d1f3a6c27
Revises: a26ae97e35f1, 9c2e5a7d4f18
Create Date: 2026-11-18 00:00:00.000000

"""

from collections.abc import Sequence

# revision identifiers, used by Alembic.
revision: str = "5b8d1f3a6c27"
down_revision: str | Sequence[str] | None = ("a26ae97e35f1", "9c2e5a7d4f18")
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Join the two heads; no schema change.

    Both branches start from the same parent and touch unrelated tables, so a
    database that already ran either one upgrades through the other and lands here.
    """


def downgrade() -> None:
    """Split back into the two heads; no schema change."""
