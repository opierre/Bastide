"""add phase2 tables

Revision ID: 69c99438379e
Revises: e4a1c6f20b73
Create Date: 2026-08-11 20:04:40.698840

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "69c99438379e"
down_revision: str | Sequence[str] | None = "e4a1c6f20b73"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create the Phase 2 tables: goals, recurring series, and categorization runs.

    Tables are created parent-first so every foreign key has its target. The two cascading
    FKs (`goal_allocations.goal_id`, `recurring_occurrences.transaction_id`) and the two
    uniqueness guarantees the detector relies on — `(account_id, merchant_key)` and
    `transaction_id` — are enforced here, in the database, not only in application code.
    """
    op.create_table(
        "goals",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("target_minor", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("target_date", sa.Date(), nullable=True),
        sa.Column("icon", sa.String(length=50), nullable=False),
        sa.Column("color", sa.String(length=20), nullable=False),
        sa.Column("status", sa.String(length=10), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("goals", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_goals_user_id"), ["user_id"], unique=False)

    op.create_table(
        "goal_allocations",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("goal_id", sa.String(length=36), nullable=False),
        sa.Column("amount_minor", sa.Integer(), nullable=False),
        sa.Column("allocated_on", sa.Date(), nullable=False),
        sa.Column("note", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["goal_id"], ["goals.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("goal_allocations", schema=None) as batch_op:
        batch_op.create_index("ix_goal_allocations_goal_id", ["goal_id"], unique=False)

    op.create_table(
        "recurring_series",
        sa.Column("id", sa.String(length=36), nullable=False),
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
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["account_id"],
            ["accounts.id"],
        ),
        sa.ForeignKeyConstraint(
            ["category_id"],
            ["categories.id"],
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "account_id", "merchant_key", name="uq_recurring_series_account_merchant"
        ),
    )
    with op.batch_alter_table("recurring_series", schema=None) as batch_op:
        batch_op.create_index(
            "ix_recurring_series_user_status", ["user_id", "status"], unique=False
        )

    op.create_table(
        "recurring_occurrences",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("series_id", sa.String(length=36), nullable=False),
        sa.Column("transaction_id", sa.String(length=36), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["series_id"],
            ["recurring_series.id"],
        ),
        sa.ForeignKeyConstraint(["transaction_id"], ["transactions.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("transaction_id", name="uq_recurring_occurrences_transaction"),
    )
    with op.batch_alter_table("recurring_occurrences", schema=None) as batch_op:
        batch_op.create_index("ix_recurring_occurrences_series_id", ["series_id"], unique=False)

    op.create_table(
        "categorization_runs",
        sa.Column("id", sa.String(length=36), nullable=False),
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
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["account_id"],
            ["accounts.id"],
        ),
        sa.ForeignKeyConstraint(
            ["import_batch_id"],
            ["import_batches.id"],
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    with op.batch_alter_table("categorization_runs", schema=None) as batch_op:
        batch_op.create_index(
            "ix_categorization_runs_user_created_at", ["user_id", "created_at"], unique=False
        )


def downgrade() -> None:
    """Drop the Phase 2 tables, children before parents so no FK is left dangling."""
    with op.batch_alter_table("categorization_runs", schema=None) as batch_op:
        batch_op.drop_index("ix_categorization_runs_user_created_at")

    op.drop_table("categorization_runs")
    with op.batch_alter_table("recurring_occurrences", schema=None) as batch_op:
        batch_op.drop_index("ix_recurring_occurrences_series_id")

    op.drop_table("recurring_occurrences")
    with op.batch_alter_table("recurring_series", schema=None) as batch_op:
        batch_op.drop_index("ix_recurring_series_user_status")

    op.drop_table("recurring_series")
    with op.batch_alter_table("goal_allocations", schema=None) as batch_op:
        batch_op.drop_index("ix_goal_allocations_goal_id")

    op.drop_table("goal_allocations")
    with op.batch_alter_table("goals", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_goals_user_id"))

    op.drop_table("goals")
