"""The hue slots a category is drawn in (`docs/design/00-design-system.md` §2.4).

A category stores a slot, never a colour: the app's theme resolves the slot to a hue, so the
same category reads correctly in the dark and the light palettes. ``cat1``–``cat10`` and ``cat0``
are the slots a custom category may pick; ``income`` is Revenus, drawn in the theme's positive
colour, and is carried by its subcategories.
"""

from typing import Literal, get_args

CategoryHue = Literal[
    "cat0",
    "cat1",
    "cat2",
    "cat3",
    "cat4",
    "cat5",
    "cat6",
    "cat7",
    "cat8",
    "cat9",
    "cat10",
    "income",
]

#: The v1 hex values the app stored before slots, mapped to the slot that replaced each.
V1_HEX_TO_SLOT: dict[str, CategoryHue] = {
    "#4FD1E8": "cat1",  # Logement
    "#5AA9FF": "cat2",  # Alimentation
    "#2DD4BF": "cat3",  # Transport
    "#FFB84D": "cat4",  # Abonnements
    "#F472B6": "cat5",  # Loisirs
    "#A3E635": "cat6",  # Santé
    "#64748B": "cat0",  # Autres, Épargne
    "#4ADE80": "income",  # Revenus
}

_SLOTS: frozenset[str] = frozenset(get_args(CategoryHue))


def slot_for(value: str) -> CategoryHue:
    """The slot a stored value stands for: itself if it is one, else its v1 hex's, else cat0."""
    if value in _SLOTS:
        return value  # ty: ignore[invalid-return-type] — membership in _SLOTS narrows to the Literal
    return V1_HEX_TO_SLOT.get(value.upper(), "cat0")
