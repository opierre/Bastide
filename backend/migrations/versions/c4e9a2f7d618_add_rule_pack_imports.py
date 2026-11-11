"""add rule pack imports

Revision ID: c4e9a2f7d618
Revises: a7d3e1c95b20
Create Date: 2026-11-11 12:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c4e9a2f7d618"
down_revision: str | Sequence[str] | None = "a7d3e1c95b20"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Record the built-in rule packs each user has imported, so the app stops offering them.

    One row per user and pack: importing the same pack twice keeps the first record.
    """
    op.create_table(
        "rule_pack_imports",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("builtin_id", sa.String(length=100), nullable=False),
        sa.Column("imported_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "builtin_id"),
    )
    with op.batch_alter_table("rule_pack_imports", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_rule_pack_imports_user_id"), ["user_id"], unique=False)


def downgrade() -> None:
    """Forget which built-in packs were imported; the app offers them again."""
    with op.batch_alter_table("rule_pack_imports", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_rule_pack_imports_user_id"))
    op.drop_table("rule_pack_imports")
