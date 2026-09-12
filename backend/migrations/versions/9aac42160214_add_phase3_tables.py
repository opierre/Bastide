"""add phase3 tables

Revision ID: 9aac42160214
Revises: a8d3f2c61e05
Create Date: 2026-09-12 20:34:06.765908

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "9aac42160214"
down_revision: str | Sequence[str] | None = "a8d3f2c61e05"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create the Phase 3 tables and add `user_settings.declared_monthly_income_minor`.

    `properties` precedes `mortgages` so the nullable `property_id` FK has its target; it sets
    null on delete, so a loan outlives the property it financed. The per-user uniqueness of tax
    profiles, brackets and parameters and the `mortgages.kind` check are enforced here, in the
    database. No derived figure (schedule, estimate, simulation result) gets a column (§4c).
    """
    op.create_table(
        "mortgage_simulations",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("label", sa.String(length=255), nullable=False),
        sa.Column("property_price_minor", sa.Integer(), nullable=False),
        sa.Column("down_payment_minor", sa.Integer(), nullable=False),
        sa.Column("principal_minor", sa.Integer(), nullable=False),
        sa.Column("annual_rate_bps", sa.Integer(), nullable=False),
        sa.Column("insurance_monthly_minor", sa.Integer(), nullable=False),
        sa.Column("term_months", sa.Integer(), nullable=False),
        sa.Column("upfront_fees_minor", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("mortgage_simulations", schema=None) as batch_op:
        batch_op.create_index(
            "ix_mortgage_simulations_user_created_at", ["user_id", "created_at"], unique=False
        )

    op.create_table(
        "properties",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("label", sa.String(length=255), nullable=False),
        sa.Column("kind", sa.String(length=20), nullable=False),
        sa.Column("market_value_minor", sa.Integer(), nullable=False),
        sa.Column("valued_on", sa.Date(), nullable=False),
        sa.Column("ownership_bps", sa.Integer(), nullable=False),
        sa.Column("acquisition_price_minor", sa.Integer(), nullable=True),
        sa.Column("acquired_on", sa.Date(), nullable=True),
        sa.Column("annual_rent_minor", sa.Integer(), nullable=True),
        sa.Column("annual_charges_minor", sa.Integer(), nullable=True),
        sa.Column("property_regime", sa.String(length=20), nullable=True),
        sa.Column("archived", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("properties", schema=None) as batch_op:
        batch_op.create_index("ix_properties_user_archived", ["user_id", "archived"], unique=False)

    op.create_table(
        "tax_brackets",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=True),
        sa.Column("tax_year", sa.Integer(), nullable=False),
        sa.Column("kind", sa.String(length=10), nullable=False),
        sa.Column("ordinal", sa.Integer(), nullable=False),
        sa.Column("lower_bound_minor", sa.Integer(), nullable=False),
        sa.Column("rate_bps", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id", "tax_year", "kind", "ordinal", name="uq_tax_brackets_user_year_kind_ordinal"
        ),
    )
    with op.batch_alter_table("tax_brackets", schema=None) as batch_op:
        batch_op.create_index(
            "ix_tax_brackets_year_kind_ordinal", ["tax_year", "kind", "ordinal"], unique=False
        )
        # NULLs are distinct in the unique constraint above; this holds system rows to one per slot.
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
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
        ),
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
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "tax_year", name="uq_tax_profiles_user_year"),
    )
    op.create_table(
        "mortgages",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("label", sa.String(length=255), nullable=False),
        sa.Column("lender", sa.String(length=255), nullable=False),
        sa.Column("property_id", sa.String(length=36), nullable=True),
        sa.Column("kind", sa.String(length=20), nullable=False),
        sa.Column("repayment_type", sa.String(length=20), nullable=False),
        sa.Column("principal_minor", sa.Integer(), nullable=False),
        sa.Column("annual_rate_bps", sa.Integer(), nullable=False),
        sa.Column("insurance_monthly_minor", sa.Integer(), nullable=False),
        sa.Column("term_months", sa.Integer(), nullable=False),
        sa.Column("first_payment_date", sa.Date(), nullable=False),
        sa.Column("upfront_fees_minor", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=10), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "kind IN ('mortgage', 'works', 'consumer', 'auto')", name="ck_mortgages_kind"
        ),
        sa.ForeignKeyConstraint(["property_id"], ["properties.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("mortgages", schema=None) as batch_op:
        batch_op.create_index("ix_mortgages_user_status", ["user_id", "status"], unique=False)

    with op.batch_alter_table("user_settings", schema=None) as batch_op:
        batch_op.add_column(sa.Column("declared_monthly_income_minor", sa.Integer(), nullable=True))


def downgrade() -> None:
    """Drop the settings column and the Phase 3 tables, `mortgages` before `properties`."""
    with op.batch_alter_table("user_settings", schema=None) as batch_op:
        batch_op.drop_column("declared_monthly_income_minor")

    with op.batch_alter_table("mortgages", schema=None) as batch_op:
        batch_op.drop_index("ix_mortgages_user_status")

    op.drop_table("mortgages")
    op.drop_table("tax_profiles")
    with op.batch_alter_table("tax_parameters", schema=None) as batch_op:
        batch_op.drop_index("uq_tax_parameters_system_year_key")
        batch_op.drop_index("ix_tax_parameters_year_key")

    op.drop_table("tax_parameters")
    with op.batch_alter_table("tax_brackets", schema=None) as batch_op:
        batch_op.drop_index("uq_tax_brackets_system_year_kind_ordinal")
        batch_op.drop_index("ix_tax_brackets_year_kind_ordinal")

    op.drop_table("tax_brackets")
    with op.batch_alter_table("properties", schema=None) as batch_op:
        batch_op.drop_index("ix_properties_user_archived")

    op.drop_table("properties")
    with op.batch_alter_table("mortgage_simulations", schema=None) as batch_op:
        batch_op.drop_index("ix_mortgage_simulations_user_created_at")

    op.drop_table("mortgage_simulations")
