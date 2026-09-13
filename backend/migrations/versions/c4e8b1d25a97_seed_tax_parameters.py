"""seed tax parameters

Revision ID: c4e8b1d25a97
Revises: 9aac42160214
Create Date: 2026-09-13 10:12:41.308215

Seeds the system (`user_id` NULL) barème and tax parameters. The figures are frozen here rather
than imported: the tax feature they served has been removed, and `b6d4f0e81a53` drops the tables.

Verification — tax year: 2025 income (imposition 2026). Checked on 2026-09-13 against the
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

# revision identifiers, used by Alembic.
revision: str = "c4e8b1d25a97"
down_revision: str | Sequence[str] | None = "9aac42160214"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_TAX_YEAR = 2025

#: Per kind, `(lower_bound_minor, rate_bps)` bands ascending; the position is the ordinal.
_BRACKETS: dict[str, tuple[tuple[int, int], ...]] = {
    "ir": (
        (0, 0),
        (1_160_000, 1100),
        (2_957_900, 3000),
        (8_457_700, 4100),
        (18_191_700, 4500),
    ),
    "ifi": (
        (0, 0),
        (80_000_000, 50),
        (130_000_000, 70),
        (257_000_000, 100),
        (500_000_000, 125),
        (1_000_000_000, 150),
    ),
}

#: `key: (int_value, unit)`.
_PARAMETERS: dict[str, tuple[int, str]] = {
    "salary_allowance_bps": (1000, "bps"),
    "salary_allowance_floor_minor": (50_900, "minor"),
    "salary_allowance_ceiling_minor": (1_455_500, "minor"),
    "quotient_half_part_cap_minor": (180_700, "minor"),
    "decote_threshold_single_minor": (89_700, "minor"),
    "decote_threshold_couple_minor": (148_300, "minor"),
    "decote_rate_bps": (4525, "bps"),
    "pfu_income_tax_bps": (1280, "bps"),
    "capital_social_charges_bps": (1860, "bps"),
    "property_social_charges_bps": (1720, "bps"),
    "dividend_allowance_bps": (4000, "bps"),
    "micro_foncier_allowance_bps": (3000, "bps"),
    "micro_foncier_ceiling_minor": (1_500_000, "minor"),
    "ifi_threshold_minor": (130_000_000, "minor"),
    "ifi_primary_residence_allowance_bps": (3000, "bps"),
    "ifi_decote_base_minor": (1_750_000, "minor"),
    "ifi_decote_rate_bps": (125, "bps"),
}

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

    for kind, bands in _BRACKETS.items():
        for ordinal, (lower_bound_minor, rate_bps) in enumerate(bands):
            existing = connection.execute(
                sa.select(_brackets.c.id).where(
                    _brackets.c.user_id.is_(None),
                    _brackets.c.tax_year == _TAX_YEAR,
                    _brackets.c.kind == kind,
                    _brackets.c.ordinal == ordinal,
                )
            ).first()
            if existing is None:
                connection.execute(
                    sa.insert(_brackets).values(
                        id=str(uuid4()),
                        user_id=None,
                        tax_year=_TAX_YEAR,
                        kind=kind,
                        ordinal=ordinal,
                        lower_bound_minor=lower_bound_minor,
                        rate_bps=rate_bps,
                    )
                )

    for key, (int_value, unit) in _PARAMETERS.items():
        existing = connection.execute(
            sa.select(_parameters.c.id).where(
                _parameters.c.user_id.is_(None),
                _parameters.c.tax_year == _TAX_YEAR,
                _parameters.c.key == key,
            )
        ).first()
        if existing is None:
            connection.execute(
                sa.insert(_parameters).values(
                    id=str(uuid4()),
                    user_id=None,
                    tax_year=_TAX_YEAR,
                    key=key,
                    int_value=int_value,
                    unit=unit,
                )
            )


def downgrade() -> None:
    """Delete only the system rows for the year; a user's overrides are their data."""
    connection = op.get_bind()
    connection.execute(
        sa.delete(_brackets).where(_brackets.c.user_id.is_(None), _brackets.c.tax_year == _TAX_YEAR)
    )
    connection.execute(
        sa.delete(_parameters).where(
            _parameters.c.user_id.is_(None), _parameters.c.tax_year == _TAX_YEAR
        )
    )
