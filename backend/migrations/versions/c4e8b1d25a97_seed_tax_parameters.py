"""seed tax parameters

Revision ID: c4e8b1d25a97
Revises: 9aac42160214
Create Date: 2026-09-13 10:12:41.308215

Seeds the system (`user_id` NULL) barème and tax parameters from `app.features.tax.seed`.

Verification (§16) — tax year: 2025 income (imposition 2026). Checked on 2026-09-13 against the
official sources below; every figure matched them as seeded.

- `ir` barème: CGI art. 197 as indexed by loi n° 2026-103 du 19 février 2026 de finances pour
  2026, art. 4 — BOI-IR-LIQ-20-10 § 40 (07/04/2026).
- 10 % salary allowance floor and ceiling: BOI-BAREME-000035 (17/02/2026).
- Quotient familial cap per half-part: BOI-IR-LIQ-20-20-20 § 40 (07/04/2026).
- Décote thresholds and rate: BOI-IR-LIQ-20-20-30 § 40 (07/04/2026).
- PFU income tax rate and 40 % dividend allowance: impots.gouv.fr « Les revenus mobiliers ».
- Prélèvements sociaux: 18,6 % on capital income (loi n° 2025-1403 du 30 décembre 2025 de
  financement de la sécurité sociale pour 2026); 17,2 % kept on revenus fonciers — impots.gouv.fr
  « Je donne un bien en location. Dois-je payer des prélèvements sociaux ? ».
- Micro-foncier ceiling and allowance: CGI art. 32 — BOI-RFPI-DECLA-10 § 90 and § 160.
- `ifi` barème and décote: CGI art. 977; threshold: CGI art. 964; primary-residence allowance:
  CGI art. 973 — BOI-PAT-IFI-20-30-20.
"""

from collections.abc import Sequence
from uuid import uuid4

import sqlalchemy as sa
from alembic import op

from app.features.tax.seed import SYSTEM_TAX_SEED

# revision identifiers, used by Alembic.
revision: str = "c4e8b1d25a97"
down_revision: str | Sequence[str] | None = "9aac42160214"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_brackets = sa.table(
    "tax_brackets",
    sa.column("id", sa.String),
    sa.column("user_id", sa.String),
    sa.column("tax_year", sa.Integer),
    sa.column("kind", sa.String),
    sa.column("ordinal", sa.Integer),
    sa.column("lower_bound_minor", sa.Integer),
    sa.column("rate_bps", sa.Integer),
)

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
    """Insert each system bracket and parameter for the year, only where it is absent."""
    connection = op.get_bind()
    year = SYSTEM_TAX_SEED.tax_year

    for kind, bands in SYSTEM_TAX_SEED.brackets.items():
        for ordinal, band in enumerate(bands):
            existing = connection.execute(
                sa.select(_brackets.c.id).where(
                    _brackets.c.user_id.is_(None),
                    _brackets.c.tax_year == year,
                    _brackets.c.kind == kind,
                    _brackets.c.ordinal == ordinal,
                )
            ).first()
            if existing is None:
                connection.execute(
                    sa.insert(_brackets).values(
                        id=str(uuid4()),
                        user_id=None,
                        tax_year=year,
                        kind=kind,
                        ordinal=ordinal,
                        lower_bound_minor=band.lower_bound_minor,
                        rate_bps=band.rate_bps,
                    )
                )

    for key, parameter in SYSTEM_TAX_SEED.parameters.items():
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
    """Delete only the system rows for the year; a user's overrides are their data."""
    connection = op.get_bind()
    year = SYSTEM_TAX_SEED.tax_year
    connection.execute(
        sa.delete(_brackets).where(_brackets.c.user_id.is_(None), _brackets.c.tax_year == year)
    )
    connection.execute(
        sa.delete(_parameters).where(
            _parameters.c.user_id.is_(None), _parameters.c.tax_year == year
        )
    )
