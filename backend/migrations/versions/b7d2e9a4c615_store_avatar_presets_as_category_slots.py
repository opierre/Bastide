"""store avatar presets as category slots

Revision ID: b7d2e9a4c615
Revises: f4b8e2d6a173
Create Date: 2026-11-21 00:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b7d2e9a4c615"
down_revision: str | Sequence[str] | None = "f4b8e2d6a173"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# The eight hue presets and the slot that replaced each (docs/design/09-settings.md §Profil).
# `green` and `iris` have no slot and become the monogram. Copied rather than imported, so this
# migration keeps meaning what it meant when written.
_HUE_TO_SLOT = {
    "preset:cyan": "preset:cat1",
    "preset:lime": "preset:cat2",
    "preset:teal": "preset:cat3",
    "preset:amber": "preset:cat4",
    "preset:pink": "preset:cat5",
    "preset:blue": "preset:cat6",
    "preset:green": "monogram",
    "preset:iris": "monogram",
}

# The two columns holding a default avatar: the user's, and the one an uploaded picture replaced.
_COLUMNS = (("users", "avatar"), ("user_avatars", "previous_choice"))


def _remap(mapping: dict[str, str]) -> None:
    for table_name, column_name in _COLUMNS:
        target = sa.table(table_name, sa.column(column_name, sa.String))
        column = target.c[column_name]
        op.execute(
            target.update()
            .where(column.in_(mapping))
            .values({column_name: sa.case(mapping, value=column)})
        )


def upgrade() -> None:
    """An avatar preset names one of the six category slots instead of one of eight hues."""
    _remap(_HUE_TO_SLOT)


def downgrade() -> None:
    """Put each slot back to the hue it replaced; a monogram stays a monogram."""
    _remap({slot: hue for hue, slot in _HUE_TO_SLOT.items() if slot != "monogram"})
