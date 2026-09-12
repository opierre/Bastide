"""Tests for the system tax seed: what the migration inserts, and what its downgrade leaves."""

import os
import subprocess
import sys
from collections.abc import Generator
from contextlib import contextmanager
from pathlib import Path
from uuid import uuid4

from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from app.features.auth.models import User
from app.features.tax.models import TaxBracket, TaxParameter
from app.features.tax.seed import SYSTEM_TAX_SEED

BACKEND_DIR = Path(__file__).resolve().parents[3]

# The revision below the seed migration, named so a later migration cannot retarget these tests.
PRE_SEED_REVISION = "9aac42160214"

YEAR = SYSTEM_TAX_SEED.tax_year

# Every scalar key §16 names, with its unit — independent of seed.py, so a key dropped from the
# seed fails here rather than silently.
SECTION_16_KEYS = {
    "salary_allowance_bps": "bps",
    "salary_allowance_floor_minor": "minor",
    "salary_allowance_ceiling_minor": "minor",
    "quotient_half_part_cap_minor": "minor",
    "decote_threshold_single_minor": "minor",
    "decote_threshold_couple_minor": "minor",
    "decote_rate_bps": "bps",
    "pfu_income_tax_bps": "bps",
    "capital_social_charges_bps": "bps",
    "property_social_charges_bps": "bps",
    "dividend_allowance_bps": "bps",
    "micro_foncier_allowance_bps": "bps",
    "micro_foncier_ceiling_minor": "minor",
    "ifi_threshold_minor": "minor",
    "ifi_primary_residence_allowance_bps": "bps",
    "ifi_decote_base_minor": "minor",
    "ifi_decote_rate_bps": "bps",
}

UNIT_BY_SUFFIX = {"_bps": "bps", "_minor": "minor", "_count": "count"}


def _alembic(command: list[str], db_path: Path) -> None:
    env = os.environ.copy()
    env["FINSTRIDE_DB_PATH"] = str(db_path)
    subprocess.run(
        [sys.executable, "-m", "alembic", *command],
        cwd=BACKEND_DIR,
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )


@contextmanager
def _session(db_path: Path) -> Generator[Session]:
    engine = create_engine(f"sqlite:///{db_path}")
    db = Session(engine)
    try:
        yield db
    finally:
        db.close()
        engine.dispose()


def _system_brackets(db: Session, kind: str) -> list[TaxBracket]:
    return list(
        db.scalars(
            select(TaxBracket)
            .where(
                TaxBracket.user_id.is_(None), TaxBracket.tax_year == YEAR, TaxBracket.kind == kind
            )
            .order_by(TaxBracket.ordinal)
        )
    )


def _system_parameters(db: Session) -> dict[str, TaxParameter]:
    rows = db.scalars(
        select(TaxParameter).where(TaxParameter.user_id.is_(None), TaxParameter.tax_year == YEAR)
    )
    return {row.key: row for row in rows}


def _unit_for(key: str) -> str | None:
    return next((unit for suffix, unit in UNIT_BY_SUFFIX.items() if key.endswith(suffix)), None)


def _migrated(tmp_path: Path) -> Path:
    db_path = tmp_path / "seeded.db"
    _alembic(["upgrade", "head"], db_path)
    return db_path


def test_seeded_rows_match_the_seed_module_exactly(tmp_path: Path) -> None:
    with _session(_migrated(tmp_path)) as db:
        kinds = set(
            db.scalars(
                select(TaxBracket.kind).where(
                    TaxBracket.user_id.is_(None), TaxBracket.tax_year == YEAR
                )
            )
        )
        assert kinds == set(SYSTEM_TAX_SEED.brackets) == {"ir", "ifi"}

        for kind, bands in SYSTEM_TAX_SEED.brackets.items():
            seeded = [
                (b.ordinal, b.lower_bound_minor, b.rate_bps) for b in _system_brackets(db, kind)
            ]
            expected = [(i, band.lower_bound_minor, band.rate_bps) for i, band in enumerate(bands)]
            assert seeded == expected, kind

        seeded_parameters = {
            key: (row.int_value, row.unit) for key, row in _system_parameters(db).items()
        }
        assert seeded_parameters == {
            key: (parameter.int_value, parameter.unit)
            for key, parameter in SYSTEM_TAX_SEED.parameters.items()
        }


def test_bands_are_contiguous_and_ascending_with_no_gap_or_overlap(tmp_path: Path) -> None:
    with _session(_migrated(tmp_path)) as db:
        for kind in ("ir", "ifi"):
            bands = _system_brackets(db, kind)
            assert [b.ordinal for b in bands] == list(range(len(bands))), kind
            assert bands[0].lower_bound_minor == 0, kind
            bounds = [b.lower_bound_minor for b in bands]
            # Each band ends where the next begins, so strictly ascending floors leave no gap and
            # no overlap; the top band's ceiling is being last.
            assert all(low < high for low, high in zip(bounds, bounds[1:], strict=False)), kind
            rates = [b.rate_bps for b in bands]
            assert rates == sorted(rates), kind


def test_every_section_16_scalar_key_is_seeded_with_its_unit(tmp_path: Path) -> None:
    with _session(_migrated(tmp_path)) as db:
        assert {key: row.unit for key, row in _system_parameters(db).items()} == SECTION_16_KEYS


def test_every_unit_is_known_and_agrees_with_its_key_suffix(tmp_path: Path) -> None:
    with _session(_migrated(tmp_path)) as db:
        for key, row in _system_parameters(db).items():
            assert row.unit in {"bps", "minor", "count"}, key
            assert _unit_for(key) == row.unit, key


def test_every_seeded_value_is_an_integer_and_no_rate_is_a_fraction(tmp_path: Path) -> None:
    for bands in SYSTEM_TAX_SEED.brackets.values():
        for band in bands:
            assert type(band.lower_bound_minor) is int
            assert type(band.rate_bps) is int
    for parameter in SYSTEM_TAX_SEED.parameters.values():
        assert type(parameter.int_value) is int

    with _session(_migrated(tmp_path)) as db:
        for kind in ("ir", "ifi"):
            for band in _system_brackets(db, kind):
                assert type(band.lower_bound_minor) is int
                assert type(band.rate_bps) is int
                assert 0 <= band.rate_bps <= 10_000
        for key, row in _system_parameters(db).items():
            assert type(row.int_value) is int, key
            if row.unit == "bps":
                # A rate written as a fraction (0.30) would be 0 here, never a real percentage.
                assert 1 <= row.int_value <= 10_000, key


def test_reseeding_a_populated_database_inserts_nothing(tmp_path: Path) -> None:
    db_path = _migrated(tmp_path)
    with _session(db_path) as db:
        brackets_before = set(db.scalars(select(TaxBracket.id)))
        parameters_before = set(db.scalars(select(TaxParameter.id)))

    # Mark the seed as not applied, then run it again over the rows it already inserted.
    _alembic(["stamp", PRE_SEED_REVISION], db_path)
    _alembic(["upgrade", "head"], db_path)

    with _session(db_path) as db:
        assert set(db.scalars(select(TaxBracket.id))) == brackets_before
        assert set(db.scalars(select(TaxParameter.id))) == parameters_before


def test_downgrade_removes_system_rows_and_keeps_a_user_override(tmp_path: Path) -> None:
    db_path = _migrated(tmp_path)
    with _session(db_path) as db:
        user = User(
            email=f"{uuid4()}@example.test",
            password_hash="hash",
            display_name="Camille",
            locale="fr",
            currency="EUR",
        )
        db.add(user)
        db.flush()
        db.add_all(
            [
                TaxParameter(
                    user_id=user.id,
                    tax_year=YEAR,
                    key="pfu_income_tax_bps",
                    int_value=1300,
                    unit="bps",
                ),
                TaxBracket(
                    user_id=user.id,
                    tax_year=YEAR,
                    kind="ir",
                    ordinal=0,
                    lower_bound_minor=0,
                    rate_bps=0,
                ),
            ]
        )
        db.commit()
        user_id = user.id

    _alembic(["downgrade", PRE_SEED_REVISION], db_path)

    with _session(db_path) as db:
        assert _system_parameters(db) == {}
        assert _system_brackets(db, "ir") == []
        assert _system_brackets(db, "ifi") == []

        override = db.scalars(select(TaxParameter).where(TaxParameter.user_id == user_id)).one()
        assert (override.key, override.int_value) == ("pfu_income_tax_bps", 1300)
        assert (
            db.scalars(select(TaxBracket).where(TaxBracket.user_id == user_id)).one().kind == "ir"
        )
