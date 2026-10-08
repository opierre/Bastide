"""make display name a unique username

Revision ID: f8a2d5c3e910
Revises: e2c6b9a14f70
Create Date: 2026-10-09 00:00:00.000000

"""

import re
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f8a2d5c3e910"
down_revision: str | Sequence[str] | None = "e2c6b9a14f70"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Frozen copy of the rule in `app.features.auth.schemas`: a migration must not change meaning
# if the app's rule later does.
_MIN, _MAX = 3, 32
_INVALID = re.compile(r"[^a-z0-9._-]+")


def _normalize(name: str) -> str:
    """Bring a free-text display name into the username format, e.g. 'Amélie R.' → 'am.lie.r'."""
    slug = _INVALID.sub(".", name.strip().lower()).strip(".")[:_MAX]
    return slug if len(slug) >= _MIN else "user"


def upgrade() -> None:
    """Rewrite existing display names into the username format, then make them unique.

    Collisions after normalizing get a numeric suffix (`amelie`, `amelie-2`, ...), oldest user
    first, so the earliest account keeps the plain name.
    """
    users = sa.table(
        "users",
        sa.column("id", sa.String),
        sa.column("display_name", sa.String),
        sa.column("created_at", sa.DateTime),
    )
    connection = op.get_bind()
    rows = connection.execute(
        sa.select(users.c.id, users.c.display_name).order_by(users.c.created_at, users.c.id)
    ).all()

    taken: set[str] = set()
    for user_id, display_name in rows:
        base = _normalize(display_name)
        name, n = base, 1
        while name in taken:
            n += 1
            suffix = f"-{n}"
            name = base[: _MAX - len(suffix)] + suffix
        taken.add(name)
        if name != display_name:
            connection.execute(
                sa.update(users).where(users.c.id == user_id).values(display_name=name)
            )

    with op.batch_alter_table("users") as batch_op:
        batch_op.create_index(batch_op.f("ix_users_display_name"), ["display_name"], unique=True)


def downgrade() -> None:
    """Drop the uniqueness. The rewritten names stay: the originals aren't kept."""
    with op.batch_alter_table("users") as batch_op:
        batch_op.drop_index(batch_op.f("ix_users_display_name"))
