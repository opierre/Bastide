"""The properties table's column types."""

from sqlalchemy import Integer, String

from app.core.db import UtcDateTime
from app.features.properties.models import Property


def test_money_is_integer_keys_uuid_strings_timestamps_utc_aware() -> None:
    for column in Property.__table__.columns:
        if column.name.endswith("_minor"):
            assert isinstance(column.type, Integer), column.name
        if column.name in ("created_at", "updated_at"):
            assert isinstance(column.type, UtcDateTime), column.name
    pk = Property.__table__.c.id
    assert isinstance(pk.type, String)
    assert pk.type.length == 36
