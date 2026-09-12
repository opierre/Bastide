"""seed hcsf limit

Revision ID: d2a7c9e4f613
Revises: c4e8b1d25a97
Create Date: 2026-09-13 15:02:18.114530

Seeds the system (`user_id` NULL) HCSF debt-ratio reference from
`app.features.tax.seed.SYSTEM_LENDING_PARAMETERS`, for the seeded tax year.

Verification (§15): 35 % maximum debt ratio, insurance included — HCSF décision n° D-HCSF-2021-7
du 29 septembre 2021, made legally binding on lenders from 1 January 2022.
"""

from collections.abc import Sequence
from uuid import uuid4

import sqlalchemy as sa
from alembic import op

from app.features.tax.seed import SYSTEM_LENDING_PARAMETERS, SYSTEM_TAX_SEED

# revision identifiers, used by Alembic.
revision: str = "d2a7c9e4f613"
down_revision: str | Sequence[str] | None = "c4e8b1d25a97"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

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
    """Insert each system lending parameter for the year, only where it is absent."""
    connection = op.get_bind()
    year = SYSTEM_TAX_SEED.tax_year

    for key, parameter in SYSTEM_LENDING_PARAMETERS.items():
        existing = connection.execute(
            sa.select(_parameters.c.id).where(
                _parameters.c.user_id.is_(None),
                _parameters.c.tax_year == year,
                _parameters.c.key == key,
            )
        ).first()
        if existing is None:
            connection.execute(
                sa.insert(_parameters).values(
                    id=str(uuid4()),
                    user_id=None,
                    tax_year=year,
                    key=key,
                    int_value=parameter.int_value,
                    unit=parameter.unit,
                )
            )


def downgrade() -> None:
    """Delete only these system rows; a user's overrides are their data."""
    op.get_bind().execute(
        sa.delete(_parameters).where(
            _parameters.c.user_id.is_(None),
            _parameters.c.tax_year == SYSTEM_TAX_SEED.tax_year,
            _parameters.c.key.in_(list(SYSTEM_LENDING_PARAMETERS)),
        )
    )
