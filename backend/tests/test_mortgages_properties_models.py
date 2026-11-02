"""Tests for the mortgage and property tables: the migration, constraints, and property FK."""

from datetime import date
from uuid import uuid4

import pytest
from sqlalchemy import Integer, String
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.db import UtcDateTime
from app.features.auth.models import User
from app.features.mortgages.models import Mortgage, MortgageSimulation
from app.features.properties.models import Property
from app.features.settings.models import UserSettings

MIGRATION_MODELS = (Mortgage, MortgageSimulation, Property)


def test_money_and_rates_are_integers_keys_uuid_strings_timestamps_utc_aware() -> None:
    for model in MIGRATION_MODELS:
        for column in model.__table__.columns:
            if column.name.endswith(("_minor", "_bps")):
                assert isinstance(column.type, Integer), f"{model.__tablename__}.{column.name}"
            if column.name in ("created_at", "updated_at"):
                assert isinstance(column.type, UtcDateTime), f"{model.__tablename__}.{column.name}"
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
