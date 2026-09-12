"""Tests for the Phase 3 schema: the migration, its constraints, and the property FK."""

import os
import subprocess
import sys
from collections.abc import Generator
from datetime import date
from pathlib import Path
from typing import Any
from uuid import uuid4

import pytest
from sqlalchemy import DateTime, Engine, Integer, String, create_engine, event, inspect
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, sessionmaker

from app.features.auth.models import User
from app.features.mortgages.models import Mortgage, MortgageSimulation
from app.features.properties.models import Property
from app.features.settings.models import UserSettings
from app.features.tax.models import TaxBracket, TaxParameter, TaxProfile

BACKEND_DIR = Path(__file__).resolve().parent.parent

# The revision *below* the Phase 3 migration, named so a later migration cannot silently
# retarget the round-trip (see test_phase2_models.py).
PRE_PHASE3_REVISION = "a8d3f2c61e05"

PHASE3_TABLES = {
    "mortgages",
    "properties",
    "tax_profiles",
    "tax_brackets",
    "tax_parameters",
    "mortgage_simulations",
}

PHASE3_MODELS = (Mortgage, MortgageSimulation, Property, TaxProfile, TaxBracket, TaxParameter)


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


def _engine_with_foreign_keys(db_path: Path) -> Engine:
    """An engine that enforces foreign keys — without the pragma SET NULL does nothing."""
    engine = create_engine(f"sqlite:///{db_path}", connect_args={"check_same_thread": False})

    @event.listens_for(engine, "connect")
    def _enable_foreign_keys(dbapi_connection: Any, connection_record: Any) -> None:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    return engine


@pytest.fixture
def migrated_session(tmp_path: Path) -> Generator[Session]:
    """A Session on a temp SQLite database built by Alembic, with FK enforcement on."""
    db_path = tmp_path / "phase3.db"
    _alembic(["upgrade", "head"], db_path)

    engine = _engine_with_foreign_keys(db_path)
    session_local = sessionmaker(bind=engine, autoflush=False, autocommit=False)
    db = session_local()
    try:
        yield db
    finally:
        db.close()
        engine.dispose()


def _schema(db_path: Path) -> tuple[set[str], set[str]]:
    """The table names and the `user_settings` column names of a migrated database."""
    engine = create_engine(f"sqlite:///{db_path}")
    inspector = inspect(engine)
    tables = set(inspector.get_table_names())
    columns = {column["name"] for column in inspector.get_columns("user_settings")}
    engine.dispose()
    return tables, columns


def test_alembic_upgrade_builds_phase3_schema_on_empty_db(tmp_path: Path) -> None:
    db_path = tmp_path / "migrated.db"
    _alembic(["upgrade", "head"], db_path)

    tables, settings_columns = _schema(db_path)
    assert PHASE3_TABLES.issubset(tables)
    assert "declared_monthly_income_minor" in settings_columns


def test_downgrade_then_upgrade_is_clean(tmp_path: Path) -> None:
    db_path = tmp_path / "roundtrip.db"
    _alembic(["upgrade", "head"], db_path)

    _alembic(["downgrade", PRE_PHASE3_REVISION], db_path)
    tables, settings_columns = _schema(db_path)
    assert not (PHASE3_TABLES & tables)
    assert "declared_monthly_income_minor" not in settings_columns

    _alembic(["upgrade", "head"], db_path)
    tables, settings_columns = _schema(db_path)
    assert PHASE3_TABLES.issubset(tables)
    assert "declared_monthly_income_minor" in settings_columns


def test_money_and_rates_are_integers_keys_uuid_strings_timestamps_utc_aware() -> None:
    for model in PHASE3_MODELS:
        for column in model.__table__.columns:
            if column.name.endswith(("_minor", "_bps")):
                assert isinstance(column.type, Integer), f"{model.__tablename__}.{column.name}"
            if column.name in ("created_at", "updated_at"):
                assert isinstance(column.type, DateTime)
                assert column.type.timezone, f"{model.__tablename__}.{column.name}"
        pk = model.__table__.c.id
        assert isinstance(pk.type, String)
        assert pk.type.length == 36

    income = UserSettings.__table__.c.declared_monthly_income_minor
    assert isinstance(income.type, Integer)
    assert income.nullable


def _seed_user(db: Session) -> User:
    user = User(
        email=f"{uuid4()}@example.test",
        password_hash="hash",
        display_name="Camille",
        locale="fr",
        currency="EUR",
    )
    db.add(user)
    db.commit()
    return user


def _property(user: User, **overrides: object) -> Property:
    kwargs: dict[str, object] = {
        "user_id": user.id,
        "label": "Résidence principale",
        "kind": "primary_residence",
        "market_value_minor": 32_000_000,
        "valued_on": date(2026, 6, 1),
    }
    kwargs.update(overrides)
    return Property(**kwargs)


def _mortgage(user: User, **overrides: object) -> Mortgage:
    kwargs: dict[str, object] = {
        "user_id": user.id,
        "label": "Résidence principale",
        "lender": "Crédit Agricole",
        "kind": "mortgage",
        "repayment_type": "constant_payment",
        "principal_minor": 25_000_000,
        "annual_rate_bps": 345,
        "insurance_monthly_minor": 4_500,
        "term_months": 300,
        "first_payment_date": date(2024, 3, 5),
        "status": "active",
    }
    kwargs.update(overrides)
    return Mortgage(**kwargs)


def _tax_profile(user: User, **overrides: object) -> TaxProfile:
    kwargs: dict[str, object] = {
        "user_id": user.id,
        "tax_year": 2025,
        "household": "single",
        "salaries_minor": 4_200_000,
    }
    kwargs.update(overrides)
    return TaxProfile(**kwargs)


def test_tax_profile_unique_per_user_and_year(migrated_session: Session) -> None:
    user = _seed_user(migrated_session)
    migrated_session.add(_tax_profile(user))
    migrated_session.commit()

    migrated_session.add(_tax_profile(user, salaries_minor=5_000_000))
    with pytest.raises(IntegrityError):
        migrated_session.commit()


def test_tax_bracket_unique_per_user_year_kind_ordinal(migrated_session: Session) -> None:
    user = _seed_user(migrated_session)
    bracket = {"tax_year": 2025, "kind": "ir", "ordinal": 1, "lower_bound_minor": 1_149_700}
    migrated_session.add(TaxBracket(user_id=user.id, rate_bps=1100, **bracket))
    migrated_session.commit()

    migrated_session.add(TaxBracket(user_id=user.id, rate_bps=1200, **bracket))
    with pytest.raises(IntegrityError):
        migrated_session.commit()


def test_tax_parameter_unique_per_user_year_key(migrated_session: Session) -> None:
    user = _seed_user(migrated_session)
    parameter = {"tax_year": 2025, "key": "pfu_income_tax_bps", "unit": "bps"}
    migrated_session.add(TaxParameter(user_id=user.id, int_value=1280, **parameter))
    migrated_session.commit()

    migrated_session.add(TaxParameter(user_id=user.id, int_value=1300, **parameter))
    with pytest.raises(IntegrityError):
        migrated_session.commit()


def test_system_rows_with_null_user_id_insert(migrated_session: Session) -> None:
    migrated_session.add_all(
        [
            TaxBracket(
                user_id=None,
                tax_year=2025,
                kind="ir",
                ordinal=0,
                lower_bound_minor=0,
                rate_bps=0,
            ),
            TaxParameter(
                user_id=None,
                tax_year=2025,
                key="micro_foncier_ceiling_minor",
                int_value=1_500_000,
                unit="minor",
            ),
        ]
    )
    migrated_session.commit()

    assert migrated_session.query(TaxBracket).one().user_id is None
    assert migrated_session.query(TaxParameter).one().user_id is None


def test_user_row_can_shadow_the_system_row_for_the_same_key(migrated_session: Session) -> None:
    user = _seed_user(migrated_session)
    parameter = {"tax_year": 2025, "key": "pfu_income_tax_bps", "unit": "bps"}
    migrated_session.add_all(
        [
            TaxParameter(user_id=None, int_value=1280, **parameter),
            TaxParameter(user_id=user.id, int_value=1300, **parameter),
        ]
    )
    migrated_session.commit()

    assert migrated_session.query(TaxParameter).count() == 2


def test_archiving_a_property_leaves_its_mortgage_linked(migrated_session: Session) -> None:
    user = _seed_user(migrated_session)
    home = _property(user)
    migrated_session.add(home)
    migrated_session.commit()
    loan = _mortgage(user, property_id=home.id)
    migrated_session.add(loan)
    migrated_session.commit()

    home.archived = True
    migrated_session.commit()

    migrated_session.refresh(loan)
    assert loan.property_id == home.id


def test_deleting_a_property_sets_its_mortgage_property_id_null(
    migrated_session: Session,
) -> None:
    user = _seed_user(migrated_session)
    home = _property(user)
    migrated_session.add(home)
    migrated_session.commit()
    migrated_session.add(_mortgage(user, property_id=home.id))
    migrated_session.commit()

    migrated_session.delete(home)
    migrated_session.commit()
    migrated_session.expire_all()

    loan = migrated_session.query(Mortgage).one()
    assert loan.property_id is None


def test_mortgage_kind_rejects_a_value_outside_the_four(migrated_session: Session) -> None:
    user = _seed_user(migrated_session)
    migrated_session.add(_mortgage(user, kind="student"))
    with pytest.raises(IntegrityError):
        migrated_session.commit()


def test_mortgage_kind_is_not_nullable(migrated_session: Session) -> None:
    user = _seed_user(migrated_session)
    migrated_session.add(_mortgage(user, kind=None))
    with pytest.raises(IntegrityError):
        migrated_session.commit()


def test_mortgage_simulation_stores_inputs(migrated_session: Session) -> None:
    user = _seed_user(migrated_session)
    migrated_session.add(
        MortgageSimulation(
            user_id=user.id,
            label="T3 Nantes",
            property_price_minor=28_000_000,
            down_payment_minor=4_000_000,
            principal_minor=26_000_000,
            annual_rate_bps=330,
            insurance_monthly_minor=3_800,
            term_months=240,
            upfront_fees_minor=150_000,
        )
    )
    migrated_session.commit()

    assert migrated_session.query(MortgageSimulation).one().principal_minor == 26_000_000
