"""merge the archived series and property address heads

Revision ID: e04266cc2e79
Revises: e5b9c3a7d214, e6b1d8a3f572
Create Date: 2026-11-02 00:00:00.000000

"""

from collections.abc import Sequence

# revision identifiers, used by Alembic.
revision: str = "e04266cc2e79"
down_revision: str | Sequence[str] | None = ("e5b9c3a7d214", "e6b1d8a3f572")
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Join the two heads; no schema change.

    Both migrations branched from the same parent and touch unrelated tables, so a
    database that already ran either one upgrades through the other and lands here.
    """


def downgrade() -> None:
    """Split back into the two heads; no schema change."""
