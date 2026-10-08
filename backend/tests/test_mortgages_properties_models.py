"""Tests for the mortgage and property tables: the migration, constraints, and property FK."""

import shutil
from datetime import date
from pathlib import Path
from uuid import uuid4

import pytest
from sqlalchemy import DateTime, Integer, String, create_engine, inspect
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.features.auth.models import User
from app.features.mortgages.models import Mortgage, MortgageSimulation
from app.features.properties.models import Property
from app.features.settings.models import UserSettings
from tests.migrations import downgrade, upgrade

# The revision *below* the migration adding these tables, named so a later migration cannot silently
# retarget the round-trip (see test_goals_recurring_runs_models.py).
PRE_MIGRATION_REVISION = "a8d3f2c61e05"

MIGRATION_TABLES = {
    "mortgages",
    "properties",
    "mortgage_simulations",
}

# Created by the same migration and dropped again when the tax feature was removed.
TAX_TABLES = {"tax_profiles", "tax_brackets", "tax_parameters"}

MIGRATION_MODELS = (Mortgage, MortgageSimulation, Property)


def _schema(db_path: Path) -> tuple[set[str], set[str]]:
    """The table names and the `user_settings` column names of a migrated database."""
    engine = create_engine(f"sqlite:///{db_path}")
    inspector = inspect(engine)
    tables = set(inspector.get_table_names())
    columns = {column["name"] for column in inspector.get_columns("user_settings")}
    engine.dispose()
    return tables, columns


def test_alembic_upgrade_builds_its_schema_on_empty_db(migrated_template: Path) -> None:
    tables, settings_columns = _schema(migrated_template)
    assert MIGRATION_TABLES.issubset(tables)
    assert not (TAX_TABLES & tables)
    assert "declared_monthly_income_minor" in settings_columns


def test_downgrade_then_upgrade_is_clean(tmp_path: Path, migrated_template: Path) -> None:
    db_path = tmp_path / "roundtrip.db"
    shutil.copyfile(migrated_template, db_path)

    downgrade(db_path, PRE_MIGRATION_REVISION)
    tables, settings_columns = _schema(db_path)
    assert not (MIGRATION_TABLES & tables)
    assert "declared_monthly_income_minor" not in settings_columns

    upgrade(db_path)
    tables, settings_columns = _schema(db_path)
    assert MIGRATION_TABLES.issubset(tables)
    assert "declared_monthly_income_minor" in settings_columns


def test_money_and_rates_are_integers_keys_uuid_strings_timestamps_utc_aware() -> None:
    for model in MIGRATION_MODELS:
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
        display_name=f"camille-{uuid4().hex[:8]}",
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
