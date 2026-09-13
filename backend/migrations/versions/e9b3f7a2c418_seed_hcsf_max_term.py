"""seed hcsf max term

Revision ID: e9b3f7a2c418
Revises: d2a7c9e4f613
Create Date: 2026-09-13 17:40:05.482117

Seeds the system (`user_id` NULL) HCSF maximum loan term, `hcsf_max_term_months_count`, from
`app.features.tax.seed.SYSTEM_LENDING_PARAMETERS`, for the seeded tax year. The simulator reads
it beside `hcsf_limit_bps` (§15, §17).

Verification (§15, checked 2026-09-13): 25 years (300 months) maximum term — HCSF décision
n° D-HCSF-2021-7 du 29 septembre 2021, legally binding on lenders from 1 January 2022 (the
27-year allowance for deferred amortisation in VEFA is not modelled: différé is deferred, §15).
"""

from collections.abc import Sequence
from uuid import uuid4

import sqlalchemy as sa
from alembic import op

from app.features.tax.seed import SYSTEM_LENDING_PARAMETERS, SYSTEM_TAX_SEED

# revision identifiers, used by Alembic.
revision: str = "e9b3f7a2c418"
down_revision: str | Sequence[str] | None = "d2a7c9e4f613"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_KEY = "hcsf_max_term_months_count"

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
    year = SYSTEM_TAX_SEED.tax_year
    parameter = SYSTEM_LENDING_PARAMETERS[_KEY]

    existing = connection.execute(
        sa.select(_parameters.c.id).where(
            _parameters.c.user_id.is_(None),
            _parameters.c.tax_year == year,
            _parameters.c.key == _KEY,
        )
    ).first()
    if existing is None:
        connection.execute(
            sa.insert(_parameters).values(
                id=str(uuid4()),
                user_id=None,
                tax_year=year,
                key=_KEY,
                int_value=parameter.int_value,
                unit=parameter.unit,
            )
        )


def downgrade() -> None:
    """Delete only this system row; a user's override is their data."""
    op.get_bind().execute(
        sa.delete(_parameters).where(
            _parameters.c.user_id.is_(None),
            _parameters.c.tax_year == SYSTEM_TAX_SEED.tax_year,
            _parameters.c.key == _KEY,
        )
    )
