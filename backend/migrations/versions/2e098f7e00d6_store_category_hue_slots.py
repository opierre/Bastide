"""store category hue slots

Revision ID: 2e098f7e00d6
Revises: c4e9a2f7d618
Create Date: 2026-11-17 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "2e098f7e00d6"
down_revision: str | Sequence[str] | None = "c4e9a2f7d618"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# The v1 hex colours and the slot that replaced each (docs/design/00-design-system.md §2.4).
# Copied rather than imported, so this migration keeps meaning what it meant when written.
_HEX_TO_SLOT = {
    "#4FD1E8": "cat1",
    "#5AA9FF": "cat2",
    "#2DD4BF": "cat3",
    "#FFB84D": "cat4",
    "#F472B6": "cat5",
    "#A3E635": "cat6",
    "#64748B": "cat0",
    "#4ADE80": "income",
}

_categories = sa.table("categories", sa.column("color", sa.String))


def upgrade() -> None:
    """A category stores a hue slot, which the theme resolves, instead of a v1 hex colour.

    Every v1 hue maps to its slot once; any other colour a user category held becomes the
    neutral ``cat0``.
    """
    color = sa.func.upper(_categories.c.color)
    op.execute(
        _categories.update().values(
            color=sa.case(
                *((color == hex_value, slot) for hex_value, slot in _HEX_TO_SLOT.items()),
                else_="cat0",
            )
        )
    )


def downgrade() -> None:
    """Put each slot back to the v1 hex it replaced."""
    op.execute(
        _categories.update().values(
            color=sa.case(
                *(
                    (_categories.c.color == slot, hex_value)
                    for hex_value, slot in _HEX_TO_SLOT.items()
                ),
                else_="#64748B",
            )
        )
    )
