"""drop property rent fields

Revision ID: c7e2a9d4b150
Revises: b6d4f0e81a53
Create Date: 2026-09-13 22:10:48.530117

`annual_rent_minor`, `annual_charges_minor` and `property_regime` existed only for the tax
estimate's property income, which `b6d4f0e81a53` removed. Nothing reads them any more, so they
go. The downgrade restores the columns nullable and empty: the dropped values are not recoverable.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c7e2a9d4b150"
down_revision: str | Sequence[str] | None = "b6d4f0e81a53"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Drop the three rent columns from `properties`."""
    with op.batch_alter_table("properties", schema=None) as batch_op:
        batch_op.drop_column("property_regime")
        batch_op.drop_column("annual_charges_minor")
        batch_op.drop_column("annual_rent_minor")


def downgrade() -> None:
    """Re-add the three columns, nullable, as `9aac42160214` created them."""
    with op.batch_alter_table("properties", schema=None) as batch_op:
        batch_op.add_column(sa.Column("annual_rent_minor", sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column("annual_charges_minor", sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column("property_regime", sa.String(length=20), nullable=True))
