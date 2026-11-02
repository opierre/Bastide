"""The mortgage tables' own guarantees: column types, the kind check, the property link."""

from datetime import date

import pytest
from sqlalchemy import Integer, String
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.db import UtcDateTime
from app.features.auth.models import User
from app.features.mortgages.models import Mortgage, MortgageSimulation
from app.features.properties.models import Property
from tests.factories import make_user


def test_money_and_rates_are_integers_keys_uuid_strings_timestamps_utc_aware() -> None:
    for model in (Mortgage, MortgageSimulation):
        for column in model.__table__.columns:
            if column.name.endswith(("_minor", "_bps")):
                assert isinstance(column.type, Integer), f"{model.__tablename__}.{column.name}"
            if column.name in ("created_at", "updated_at"):
                assert isinstance(column.type, UtcDateTime), f"{model.__tablename__}.{column.name}"
        pk = model.__table__.c.id
        assert isinstance(pk.type, String)
        assert pk.type.length == 36


def _mortgage(user: User, **overrides: object) -> Mortgage:
    kwargs: dict[str, object] = {
        "user_id": user.id,
        "label": "Résidence principale",
        "lender": "Banque du Port",
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


def test_a_kind_outside_the_four_is_rejected(db_session: Session) -> None:
    db_session.add(_mortgage(make_user(db_session), kind="student"))
    with pytest.raises(IntegrityError):
        db_session.commit()


def test_the_kind_is_required(db_session: Session) -> None:
    db_session.add(_mortgage(make_user(db_session), kind=None))
    with pytest.raises(IntegrityError):
        db_session.commit()


def test_deleting_a_property_unlinks_its_mortgage(db_session: Session) -> None:
    user = make_user(db_session)
    home = Property(
        user_id=user.id,
        label="Résidence principale",
        kind="primary_residence",
        market_value_minor=32_000_000,
        valued_on=date(2026, 6, 1),
    )
    db_session.add(home)
    db_session.commit()
    db_session.add(_mortgage(user, property_id=home.id))
    db_session.commit()

    db_session.delete(home)
    db_session.commit()
    db_session.expire_all()

    assert db_session.query(Mortgage).one().property_id is None
