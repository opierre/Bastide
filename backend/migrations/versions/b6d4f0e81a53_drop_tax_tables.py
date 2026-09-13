"""drop tax tables

Revision ID: b6d4f0e81a53
Revises: e9b3f7a2c418
Create Date: 2026-09-13 21:05:37.214906

The tax estimation feature is removed: its tables go with it, user rows and seeded rows alike.
The HCSF references the mortgages feature read from `tax_parameters` are constants in that
feature now.

The downgrade recreates the three tables empty. The seeded system rows are not restored: they
belong to `c4e8b1d25a97`, `d2a7c9e4f613` and `e9b3f7a2c418`, which reinsert them when the chain is
downgraded past them and upgraded again.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b6d4f0e81a53"
down_revision: str | Sequence[str] | None = "e9b3f7a2c418"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Drop `tax_profiles`, `tax_parameters` and `tax_brackets` with their indexes."""
    op.drop_table("tax_profiles")
    with op.batch_alter_table("tax_parameters", schema=None) as batch_op:
        batch_op.drop_index("uq_tax_parameters_system_year_key")
        batch_op.drop_index("ix_tax_parameters_year_key")
    op.drop_table("tax_parameters")
    with op.batch_alter_table("tax_brackets", schema=None) as batch_op:
        batch_op.drop_index("uq_tax_brackets_system_year_kind_ordinal")
        batch_op.drop_index("ix_tax_brackets_year_kind_ordinal")
    op.drop_table("tax_brackets")


def downgrade() -> None:
    """Recreate the three tables as `9aac42160214` built them, empty."""
    op.create_table(
        "tax_brackets",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=True),
        sa.Column("tax_year", sa.Integer(), nullable=False),
        sa.Column("kind", sa.String(length=10), nullable=False),
        sa.Column("ordinal", sa.Integer(), nullable=False),
        sa.Column("lower_bound_minor", sa.Integer(), nullable=False),
        sa.Column("rate_bps", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id", "tax_year", "kind", "ordinal", name="uq_tax_brackets_user_year_kind_ordinal"
        ),
    )
    with op.batch_alter_table("tax_brackets", schema=None) as batch_op:
        batch_op.create_index(
            "ix_tax_brackets_year_kind_ordinal", ["tax_year", "kind", "ordinal"], unique=False
        )
        batch_op.create_index(
            "uq_tax_brackets_system_year_kind_ordinal",
            ["tax_year", "kind", "ordinal"],
            unique=True,
            sqlite_where=sa.text("user_id IS NULL"),
            postgresql_where=sa.text("user_id IS NULL"),
        )

    op.create_table(
        "tax_parameters",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=True),
        sa.Column("tax_year", sa.Integer(), nullable=False),
        sa.Column("key", sa.String(length=64), nullable=False),
        sa.Column("int_value", sa.Integer(), nullable=False),
        sa.Column("unit", sa.String(length=10), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "tax_year", "key", name="uq_tax_parameters_user_year_key"),
    )
    with op.batch_alter_table("tax_parameters", schema=None) as batch_op:
        batch_op.create_index("ix_tax_parameters_year_key", ["tax_year", "key"], unique=False)
        batch_op.create_index(
            "uq_tax_parameters_system_year_key",
            ["tax_year", "key"],
            unique=True,
            sqlite_where=sa.text("user_id IS NULL"),
            postgresql_where=sa.text("user_id IS NULL"),
        )

    op.create_table(
        "tax_profiles",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("tax_year", sa.Integer(), nullable=False),
        sa.Column("household", sa.String(length=10), nullable=False),
        sa.Column("dependents_count", sa.Integer(), nullable=False),
        sa.Column("single_parent", sa.Boolean(), nullable=False),
        sa.Column("salaries_minor", sa.Integer(), nullable=False),
        sa.Column("pensions_minor", sa.Integer(), nullable=False),
        sa.Column("dividends_minor", sa.Integer(), nullable=False),
        sa.Column("interest_minor", sa.Integer(), nullable=False),
        sa.Column("capital_gains_minor", sa.Integer(), nullable=False),
        sa.Column("pfu_opt_out", sa.Boolean(), nullable=False),
        sa.Column("deductions_minor", sa.Integer(), nullable=False),
        sa.Column("credits_minor", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "tax_year", name="uq_tax_profiles_user_year"),
    )
