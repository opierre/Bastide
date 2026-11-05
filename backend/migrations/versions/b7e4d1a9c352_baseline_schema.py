"""baseline schema at v0.1.0

Revision ID: b7e4d1a9c352
Revises:
Create Date: 2026-11-05 00:00:00.000000

The 20 migrations up to v0.1.0's head, squashed into one. The revision ID is that head's, so every
released install (v0.1.0 sits here, v0.1.1 and v0.1.2 are past it) carries on from it unchanged.
A database still stamped with one of the revisions folded in here is refused at startup: see
`SQUASHED_REVISIONS` in `app/core/schema.py`.

It builds the schema the old chain left at this revision, column order included, minus what
that chain added and then dropped again (CSV templates, tax tables, the rent fields) and the
data steps that only touched rows already gone (tax and HCSF seeds, placeholder memos, the
display-name rewrite).
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b7e4d1a9c352"
down_revision: str | Sequence[str] | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _id() -> sa.Column:
    return sa.Column("id", sa.String(length=36), nullable=False)


def _timestamp(name: str, *, nullable: bool = False) -> sa.Column:
    return sa.Column(name, sa.DateTime(timezone=True), nullable=nullable)


def upgrade() -> None:
    """Create every table and index as v0.1.0 had them."""
    op.create_table(
        "users",
        _id(),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column("display_name", sa.String(length=255), nullable=False),
        sa.Column("locale", sa.String(length=5), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        _timestamp("created_at"),
        _timestamp("updated_at"),
        sa.Column("recovery_code_hash", sa.String(length=255), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_users_display_name", "users", ["display_name"], unique=True)
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "accounts",
        _id(),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("type", sa.String(length=20), nullable=False),
        sa.Column("institution", sa.String(length=255), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("ofx_account_id", sa.String(length=255), nullable=True),
        sa.Column("opening_balance_minor", sa.Integer(), nullable=False),
        sa.Column("archived", sa.Boolean(), nullable=False),
        sa.Column("cached_balance_minor", sa.Integer(), nullable=False),
        _timestamp("created_at"),
        _timestamp("updated_at"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "ofx_account_id", name="uq_accounts_user_ofx_account_id"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
    )
    op.create_index("ix_accounts_user_id", "accounts", ["user_id"], unique=False)

    op.create_table(
        "auth_tokens",
        _id(),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("token", sa.String(length=64), nullable=False),
        _timestamp("created_at"),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
    )
    op.create_index("ix_auth_tokens_token", "auth_tokens", ["token"], unique=True)
    op.create_index("ix_auth_tokens_user_id", "auth_tokens", ["user_id"], unique=False)

    op.create_table(
        "categories",
        _id(),
        sa.Column("user_id", sa.String(length=36), nullable=True),
        sa.Column("parent_id", sa.String(length=36), nullable=True),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("kind", sa.String(length=10), nullable=False),
        sa.Column("icon", sa.String(length=50), nullable=False),
        sa.Column("color", sa.String(length=7), nullable=False),
        sa.Column("is_system", sa.Boolean(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["parent_id"], ["categories.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
    )
    op.create_index("ix_categories_parent_id", "categories", ["parent_id"], unique=False)
    op.create_index("ix_categories_user_id", "categories", ["user_id"], unique=False)

    op.create_table(
        "account_balance_snapshots",
        _id(),
        sa.Column("account_id", sa.String(length=36), nullable=False),
        sa.Column("period_end", sa.Date(), nullable=False),
        sa.Column("balance_minor", sa.Integer(), nullable=False),
        _timestamp("created_at"),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["account_id"], ["accounts.id"]),
        sa.UniqueConstraint("account_id", "period_end"),
    )
    op.create_index(
        "ix_account_balance_snapshots_account_id",
        "account_balance_snapshots",
        ["account_id"],
        unique=False,
    )

    op.create_table(
        "categorization_rules",
        _id(),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("priority", sa.Integer(), nullable=False),
        sa.Column("match_field", sa.String(length=20), nullable=False),
        sa.Column("match_type", sa.String(length=10), nullable=False),
        sa.Column("pattern", sa.String(length=255), nullable=False),
        sa.Column("category_id", sa.String(length=36), nullable=False),
        sa.Column("enabled", sa.Boolean(), nullable=False),
        _timestamp("created_at"),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["category_id"], ["categories.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
    )
    op.create_index(
        "ix_categorization_rules_user_id", "categorization_rules", ["user_id"], unique=False
    )

    op.create_table(
        "import_batches",
        _id(),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("account_id", sa.String(length=36), nullable=False),
        sa.Column("source_format", sa.String(length=10), nullable=False),
        sa.Column("file_name", sa.String(length=255), nullable=False),
        sa.Column("file_hash", sa.String(length=64), nullable=False),
        sa.Column("period_start", sa.Date(), nullable=False),
        sa.Column("period_end", sa.Date(), nullable=False),
        sa.Column("transaction_count", sa.Integer(), nullable=False),
        sa.Column("new_count", sa.Integer(), nullable=False),
        sa.Column("duplicate_count", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=10), nullable=False),
        sa.Column("error_message", sa.String(), nullable=True),
        _timestamp("imported_at"),
        sa.Column("balance_mismatch_minor", sa.Integer(), nullable=True),
        sa.Column("balance_mismatch_as_of", sa.Date(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["account_id"], ["accounts.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.UniqueConstraint("account_id", "file_hash"),
    )
    op.create_index("ix_import_batches_account_id", "import_batches", ["account_id"], unique=False)
    op.create_index("ix_import_batches_user_id", "import_batches", ["user_id"], unique=False)

    op.create_table(
        "transactions",
        _id(),
        sa.Column("account_id", sa.String(length=36), nullable=False),
        sa.Column("import_batch_id", sa.String(length=36), nullable=False),
        sa.Column("booked_date", sa.Date(), nullable=False),
        sa.Column("value_date", sa.Date(), nullable=True),
        sa.Column("amount_minor", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("description_raw", sa.String(), nullable=False),
        sa.Column("description_clean", sa.String(), nullable=False),
        sa.Column("merchant", sa.String(length=255), nullable=True),
        sa.Column("category_id", sa.String(length=36), nullable=True),
        sa.Column("categorization_source", sa.String(length=20), nullable=False),
        sa.Column("categorization_confidence", sa.Float(), nullable=True),
        sa.Column("needs_review", sa.Boolean(), nullable=False),
        sa.Column("fitid", sa.String(length=255), nullable=True),
        sa.Column("dedup_hash", sa.String(length=64), nullable=False),
        _timestamp("created_at"),
        _timestamp("updated_at"),
        sa.Column("memo", sa.String(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["account_id"], ["accounts.id"]),
        sa.ForeignKeyConstraint(["category_id"], ["categories.id"]),
        sa.ForeignKeyConstraint(["import_batch_id"], ["import_batches.id"]),
    )
    op.create_index(
        "ix_transactions_account_dedup_hash",
        "transactions",
        ["account_id", "dedup_hash"],
        unique=False,
    )
    op.create_index(
        "ix_transactions_account_fitid", "transactions", ["account_id", "fitid"], unique=True
    )
    op.create_index("ix_transactions_account_id", "transactions", ["account_id"], unique=False)
    op.create_index("ix_transactions_category_id", "transactions", ["category_id"], unique=False)
    op.create_index(
        "ix_transactions_import_batch_id", "transactions", ["import_batch_id"], unique=False
    )

    op.create_table(
        "user_settings",
        _id(),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("ai_enabled", sa.Boolean(), nullable=False),
        sa.Column("inference_base_url", sa.String(length=255), nullable=False),
        sa.Column("model_tag", sa.String(length=255), nullable=True),
        sa.Column("confidence_threshold", sa.Float(), nullable=False),
        _timestamp("created_at"),
        _timestamp("updated_at"),
        _timestamp("last_backup_at", nullable=True),
        sa.Column("declared_monthly_income_minor", sa.Integer(), nullable=True),
        sa.Column("update_check_enabled", sa.Boolean(), nullable=False, server_default=sa.false()),
        _timestamp("update_checked_at", nullable=True),
        sa.Column("update_latest_version", sa.String(length=64), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.UniqueConstraint("user_id"),
    )

    op.create_table(
        "categorization_runs",
        _id(),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("account_id", sa.String(length=36), nullable=True),
        sa.Column("import_batch_id", sa.String(length=36), nullable=True),
        sa.Column("trigger", sa.String(length=10), nullable=False),
        sa.Column("status", sa.String(length=10), nullable=False),
        sa.Column("model_tag", sa.String(length=255), nullable=True),
        sa.Column("total_count", sa.Integer(), nullable=False),
        sa.Column("processed_count", sa.Integer(), nullable=False),
        sa.Column("assigned_count", sa.Integer(), nullable=False),
        sa.Column("deferred_count", sa.Integer(), nullable=False),
        sa.Column("failed_count", sa.Integer(), nullable=False),
        sa.Column("error_message", sa.String(), nullable=True),
        _timestamp("started_at", nullable=True),
        _timestamp("finished_at", nullable=True),
        _timestamp("created_at"),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["account_id"], ["accounts.id"]),
        sa.ForeignKeyConstraint(["import_batch_id"], ["import_batches.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
    )
    op.create_index(
        "ix_categorization_runs_user_created_at",
        "categorization_runs",
        ["user_id", "created_at"],
        unique=False,
    )

    op.create_table(
        "recurring_series",
        _id(),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("account_id", sa.String(length=36), nullable=False),
        sa.Column("merchant_key", sa.String(length=255), nullable=False),
        sa.Column("label", sa.String(length=255), nullable=False),
        sa.Column("category_id", sa.String(length=36), nullable=True),
        sa.Column("cadence", sa.String(length=10), nullable=False),
        sa.Column("median_interval_days", sa.Integer(), nullable=False),
        sa.Column("expected_amount_minor", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("first_seen_date", sa.Date(), nullable=False),
        sa.Column("last_seen_date", sa.Date(), nullable=False),
        sa.Column("next_expected_date", sa.Date(), nullable=False),
        sa.Column("occurrence_count", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=10), nullable=False),
        sa.Column("is_manual", sa.Boolean(), nullable=False),
        sa.Column("price_change_minor", sa.Integer(), nullable=True),
        sa.Column("price_changed_at", sa.Date(), nullable=True),
        _timestamp("created_at"),
        _timestamp("updated_at"),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["account_id"], ["accounts.id"]),
        sa.ForeignKeyConstraint(["category_id"], ["categories.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.UniqueConstraint(
            "account_id", "merchant_key", name="uq_recurring_series_account_merchant"
        ),
    )
    op.create_index(
        "ix_recurring_series_user_status", "recurring_series", ["user_id", "status"], unique=False
    )

    op.create_table(
        "recurring_occurrences",
        _id(),
        sa.Column("series_id", sa.String(length=36), nullable=False),
        sa.Column("transaction_id", sa.String(length=36), nullable=False),
        _timestamp("created_at"),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["series_id"], ["recurring_series.id"]),
        sa.ForeignKeyConstraint(["transaction_id"], ["transactions.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("transaction_id", name="uq_recurring_occurrences_transaction"),
    )
    op.create_index(
        "ix_recurring_occurrences_series_id", "recurring_occurrences", ["series_id"], unique=False
    )

    op.create_table(
        "goals",
        _id(),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("target_minor", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("target_date", sa.Date(), nullable=True),
        sa.Column("icon", sa.String(length=50), nullable=False),
        sa.Column("color", sa.String(length=20), nullable=False),
        sa.Column("status", sa.String(length=10), nullable=False),
        _timestamp("created_at"),
        _timestamp("updated_at"),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
    )
    op.create_index("ix_goals_user_id", "goals", ["user_id"], unique=False)

    op.create_table(
        "goal_allocations",
        _id(),
        sa.Column("goal_id", sa.String(length=36), nullable=False),
        sa.Column("amount_minor", sa.Integer(), nullable=False),
        sa.Column("allocated_on", sa.Date(), nullable=False),
        sa.Column("note", sa.String(), nullable=True),
        _timestamp("created_at"),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["goal_id"], ["goals.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_goal_allocations_goal_id", "goal_allocations", ["goal_id"], unique=False)

    op.create_table(
        "properties",
        _id(),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("label", sa.String(length=255), nullable=False),
        sa.Column("kind", sa.String(length=20), nullable=False),
        sa.Column("market_value_minor", sa.Integer(), nullable=False),
        sa.Column("valued_on", sa.Date(), nullable=False),
        sa.Column("ownership_bps", sa.Integer(), nullable=False),
        sa.Column("acquisition_price_minor", sa.Integer(), nullable=True),
        sa.Column("acquired_on", sa.Date(), nullable=True),
        sa.Column("archived", sa.Boolean(), nullable=False),
        _timestamp("created_at"),
        _timestamp("updated_at"),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
    )
    op.create_index(
        "ix_properties_user_archived", "properties", ["user_id", "archived"], unique=False
    )

    op.create_table(
        "mortgages",
        _id(),
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
        _timestamp("created_at"),
        _timestamp("updated_at"),
        sa.PrimaryKeyConstraint("id"),
        sa.CheckConstraint(
            "kind IN ('mortgage', 'works', 'consumer', 'auto')", name="ck_mortgages_kind"
        ),
        sa.ForeignKeyConstraint(["property_id"], ["properties.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
    )
    op.create_index("ix_mortgages_user_status", "mortgages", ["user_id", "status"], unique=False)

    op.create_table(
        "mortgage_simulations",
        _id(),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("label", sa.String(length=255), nullable=False),
        sa.Column("property_price_minor", sa.Integer(), nullable=False),
        sa.Column("down_payment_minor", sa.Integer(), nullable=False),
        sa.Column("principal_minor", sa.Integer(), nullable=False),
        sa.Column("annual_rate_bps", sa.Integer(), nullable=False),
        sa.Column("insurance_monthly_minor", sa.Integer(), nullable=False),
        sa.Column("term_months", sa.Integer(), nullable=False),
        sa.Column("upfront_fees_minor", sa.Integer(), nullable=False),
        _timestamp("created_at"),
        _timestamp("updated_at"),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
    )
    op.create_index(
        "ix_mortgage_simulations_user_created_at",
        "mortgage_simulations",
        ["user_id", "created_at"],
        unique=False,
    )


def downgrade() -> None:
    """Drop everything, children first: the baseline has nothing below it to go back to."""
    for table in (
        "mortgage_simulations",
        "mortgages",
        "properties",
        "goal_allocations",
        "goals",
        "recurring_occurrences",
        "recurring_series",
        "categorization_runs",
        "user_settings",
        "transactions",
        "import_batches",
        "categorization_rules",
        "account_balance_snapshots",
        "categories",
        "auth_tokens",
        "accounts",
        "users",
    ):
        op.drop_table(table)
