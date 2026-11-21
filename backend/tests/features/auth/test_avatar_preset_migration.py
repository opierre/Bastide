"""The migration that turns the eight hue avatar presets into the six category slots."""

import shutil
from pathlib import Path

import pytest
from sqlalchemy import create_engine, text

from tests.migrations import downgrade, upgrade

_BEFORE = "f4b8e2d6a173"

# Old stored value → value after the migration.
_MAPPING = {
    "preset:cyan": "preset:cat1",
    "preset:lime": "preset:cat2",
    "preset:teal": "preset:cat3",
    "preset:amber": "preset:cat4",
    "preset:pink": "preset:cat5",
    "preset:blue": "preset:cat6",
    "preset:green": "monogram",
    "preset:iris": "monogram",
    "monogram": "monogram",
    "image": "image",
}


@pytest.fixture
def db_before(tmp_path: Path, migrated_template: Path) -> Path:
    """A database one revision before the avatar slots, with one user per stored value."""
    db_path = tmp_path / "avatars.db"
    shutil.copyfile(migrated_template, db_path)
    downgrade(db_path, _BEFORE)
    engine = create_engine(f"sqlite:///{db_path}")
    with engine.begin() as connection:
        for index, avatar in enumerate(_MAPPING):
            connection.execute(
                text(
                    "INSERT INTO users (id, email, password_hash, display_name, locale, currency,"
                    " avatar, theme, created_at, updated_at) VALUES (:id, :email, 'x', :name,"
                    " 'fr', 'EUR', :avatar, 'dark', '2026-01-01 00:00:00',"
                    " '2026-01-01 00:00:00')"
                ),
                {
                    "id": f"user-{index}",
                    "email": f"user{index}@example.com",
                    "name": f"user{index}",
                    "avatar": avatar,
                },
            )
            # Every user also has a picture whose fallback is that same value.
            connection.execute(
                text(
                    "INSERT INTO user_avatars (user_id, image, content_type, previous_choice,"
                    " updated_at) VALUES (:id, x'00', 'image/png', :avatar,"
                    " '2026-01-01 00:00:00')"
                ),
                {"id": f"user-{index}", "avatar": avatar},
            )
    engine.dispose()
    return db_path


def _stored(db_path: Path) -> dict[str, tuple[str, str]]:
    engine = create_engine(f"sqlite:///{db_path}")
    with engine.connect() as connection:
        rows = connection.execute(
            text(
                "SELECT users.email, users.avatar, user_avatars.previous_choice FROM users"
                " JOIN user_avatars ON user_avatars.user_id = users.id"
            )
        )
        result = {email: (avatar, previous) for email, avatar, previous in rows}
    engine.dispose()
    return result


def _expected(values: dict[str, str]) -> dict[str, tuple[str, str]]:
    return {f"user{i}@example.com": (value, value) for i, value in enumerate(values.values())}


def test_upgrade_maps_every_hue_to_its_slot_or_the_monogram(db_before: Path) -> None:
    upgrade(db_before)

    assert _stored(db_before) == _expected(_MAPPING)


def test_downgrade_puts_each_slot_back_to_its_hue(db_before: Path) -> None:
    upgrade(db_before)
    downgrade(db_before, _BEFORE)

    # `green` and `iris` were folded into the monogram, which stays one.
    restored = {old: old if new.startswith("preset:") else new for old, new in _MAPPING.items()}
    assert _stored(db_before) == _expected(restored)
