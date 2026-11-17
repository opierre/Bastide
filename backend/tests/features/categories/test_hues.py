"""Tests for the category hue slots."""

from pathlib import Path

import pytest
from sqlalchemy import text

from app.features.categories.hues import slot_for
from tests.migrations import downgrade, engine_with_foreign_keys, upgrade


@pytest.mark.parametrize(
    ("stored", "slot"),
    [
        ("cat4", "cat4"),
        ("income", "income"),
        ("#4FD1E8", "cat1"),
        ("#a3e635", "cat6"),
        ("#4ADE80", "income"),
        ("#123456", "cat0"),
    ],
)
def test_slot_for_maps_a_stored_value_to_its_slot(stored: str, slot: str) -> None:
    assert slot_for(stored) == slot


def test_migration_maps_v1_hex_colours_to_slots(tmp_path: Path) -> None:
    db_path = tmp_path / "slots.db"
    upgrade(db_path, "c4e9a2f7d618")
    engine = engine_with_foreign_keys(db_path)
    rows = {"a": "#5AA9FF", "b": "#f472b6", "c": "#4ADE80", "d": "#8B5CF6"}
    with engine.begin() as connection:
        for category_id, color in rows.items():
            connection.execute(
                text(
                    "INSERT INTO categories (id, name, kind, icon, color, is_system) "
                    "VALUES (:id, :id, 'expense', 'x', :color, 0)"
                ),
                {"id": category_id, "color": color},
            )
    engine.dispose()

    upgrade(db_path, "2e098f7e00d6")
    engine = engine_with_foreign_keys(db_path)
    with engine.connect() as connection:
        slots = {
            row.id: row.color
            for row in connection.execute(text("SELECT id, color FROM categories"))
        }
    engine.dispose()
    assert slots == {"a": "cat2", "b": "cat5", "c": "income", "d": "cat0"}

    downgrade(db_path, "c4e9a2f7d618")
    engine = engine_with_foreign_keys(db_path)
    with engine.connect() as connection:
        restored = {
            row.id: row.color
            for row in connection.execute(text("SELECT id, color FROM categories"))
        }
    engine.dispose()
    assert restored == {"a": "#5AA9FF", "b": "#F472B6", "c": "#4ADE80", "d": "#64748B"}
