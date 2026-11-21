"""Tests for the category hue slots."""

import pytest

from app.features.categories.hues import slot_for


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
