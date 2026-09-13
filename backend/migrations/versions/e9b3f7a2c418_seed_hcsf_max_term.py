"""seed hcsf max term

Revision ID: e9b3f7a2c418
Revises: d2a7c9e4f613
Create Date: 2026-09-13 17:40:05.482117

Seeds the system (`user_id` NULL) HCSF maximum loan term, `hcsf_max_term_months_count`, for the
seeded tax year. Frozen here: the mortgages feature now holds it as a constant, and
`b6d4f0e81a53` drops the table.

Verification (§15, checked 2026-09-13): 25 years (300 months) maximum term — HCSF décision
n° D-HCSF-2021-7 du 29 septembre 2021, legally binding on lenders from 1 January 2022 (the
27-year allowance for deferred amortisation in VEFA is not modelled: différé is deferred, §15).
"""

from collections.abc import Sequence
from uuid import uuid4

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e9b3f7a2c418"
down_revision: str | Sequence[str] | None = "d2a7c9e4f613"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_TAX_YEAR = 2025
_KEY = "hcsf_max_term_months_count"
_INT_VALUE = 300
_UNIT = "count"

_parameters = sa.table(
    "tax_parameters",
    sa.column("id", sa.String),
    sa.column("user_id", sa.String),
    sa.column("tax_year", sa.Integer),
    sa.column("key", sa.String),
    sa.column("int_value", sa.Integer),
    sa.column("unit", sa.String),
)


def upgrade() -> None:
    """Insert the system maximum term for the year, only where it is absent."""
    connection = op.get_bind()

    existing = connection.execute(
        sa.select(_parameters.c.id).where(
            _parameters.c.user_id.is_(None),
            _parameters.c.tax_year == _TAX_YEAR,
            _parameters.c.key == _KEY,
        )
    ).first()
    if existing is None:
        connection.execute(
            sa.insert(_parameters).values(
                id=str(uuid4()),
                user_id=None,
                tax_year=_TAX_YEAR,
                key=_KEY,
                int_value=_INT_VALUE,
                unit=_UNIT,
            )
        )


def downgrade() -> None:
    """Delete only this system row; a user's override is their data."""
    op.get_bind().execute(
        sa.delete(_parameters).where(
            _parameters.c.user_id.is_(None),
            _parameters.c.tax_year == _TAX_YEAR,
            _parameters.c.key == _KEY,
        )
    )
