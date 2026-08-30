"""drop csv templates

Revision ID: f5c81a930d47
Revises: 69c99438379e
Create Date: 2026-08-30 10:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f5c81a930d47"
down_revision: str | Sequence[str] | None = "69c99438379e"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Drop the saved per-bank CSV mappings along with the CSV import path.

    Import is OFX/QFX only: a statement carries its own account block, so the file names
    its destination instead of the user picking one. No table referenced `csv_templates`,
    so this drops cleanly. `import_batches` rows written when CSV imports existed keep
    their `source_format = 'csv'` — the history is an audit trail and is never rewritten.
    """
    with op.batch_alter_table("csv_templates", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_csv_templates_user_id"))

    op.drop_table("csv_templates")


def downgrade() -> None:
    """Recreate the table as it stood at revision 662ad14df059 (with `header_offset`).

    Structure only — the mappings themselves are gone once the upgrade has run.
    """
    op.create_table(
        "csv_templates",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("bank_name", sa.String(length=255), nullable=False),
        sa.Column("delimiter", sa.String(length=1), nullable=False),
        sa.Column("encoding", sa.String(length=20), nullable=False),
        sa.Column("date_format", sa.String(length=20), nullable=False),
        sa.Column("decimal_separator", sa.String(length=1), nullable=False),
        sa.Column("amount_strategy", sa.String(length=20), nullable=False),
        sa.Column("column_map", sa.JSON(), nullable=False),
        sa.Column("header_offset", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("csv_templates", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_csv_templates_user_id"), ["user_id"], unique=False)
