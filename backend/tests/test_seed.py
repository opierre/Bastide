"""Tests for the idempotent, localized system category seed."""

import json
from collections.abc import Iterator
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.seed import SYSTEM_CATEGORIES, CategorySeed, seed_categories
from app.features.categories.models import Category
from app.features.categorization.prompt import leaf_categories
from tests.factories import make_user

VALID_KINDS = {"income", "expense", "transfer"}

_FRONTEND = Path(__file__).resolve().parents[2] / "frontend"

# Every key the catalog has ever shipped. Rules and rule packs reference categories by key, so
# none of these may be renamed, moved to another parent or dropped. Append, never edit.
SHIPPED_KEYS = frozenset(
    {
        "category.housing",
        "category.housing.rent",
        "category.housing.mortgage",
        "category.housing.utilities",
        "category.housing.home_insurance",
        "category.housing.condo_fees",
        "category.housing.maintenance",
        "category.housing.home_services",
        "category.food",
        "category.food.groceries",
        "category.food.restaurants",
        "category.food.coffee",
        "category.food.takeaway",
        "category.food.canteen",
        "category.transport",
        "category.transport.fuel",
        "category.transport.public_transit",
        "category.transport.parking",
        "category.transport.car_maintenance",
        "category.transport.car_insurance",
        "category.transport.tolls",
        "category.transport.taxi",
        "category.transport.rental",
        "category.health",
        "category.health.doctor",
        "category.health.pharmacy",
        "category.health.insurance",
        "category.health.dentist",
        "category.health.optician",
        "category.leisure",
        "category.leisure.outings",
        "category.leisure.travel",
        "category.leisure.accommodation",
        "category.leisure.sports",
        "category.leisure.culture",
        "category.subscriptions",
        "category.shopping",
        "category.shopping.clothing",
        "category.shopping.electronics",
        "category.shopping.home",
        "category.shopping.personal_care",
        "category.shopping.gifts",
        "category.finance",
        "category.finance.bank_fees",
        "category.finance.taxes",
        "category.finance.savings",
        "category.finance.card_settlement",
        "category.finance.interest",
        "category.finance.investments",
        "category.finance.loans",
        "category.income",
        "category.income.salary",
        "category.income.pension",
        "category.income.dividends",
        "category.income.refunds",
        "category.income.benefits",
        "category.income.rental",
        "category.income.sales",
        "category.income.other",
        "category.other",
        "category.other.uncategorized",
        "category.other.cash",
        "category.other.donations",
        "category.children",
        "category.children.childcare",
        "category.children.school",
        "category.children.activities",
        "category.pets",
        "category.pets.food",
        "category.pets.vet",
    }
)


def _flatten(nodes: tuple[CategorySeed, ...]) -> Iterator[CategorySeed]:
    for node in nodes:
        yield node
        yield from _flatten(node.children)


def test_catalog_is_rich_and_fully_localized() -> None:
    nodes = list(_flatten(SYSTEM_CATEGORIES))

    assert len(nodes) >= 25
    for node in nodes:
        assert node.name_fr.strip()
        assert node.name_en.strip()
        assert node.kind in VALID_KINDS


def test_shipped_keys_are_never_renamed_or_dropped() -> None:
    keys = [node.key for node in _flatten(SYSTEM_CATEGORIES)]

    assert len(keys) == len(set(keys))
    assert set(keys) >= SHIPPED_KEYS


def test_every_key_sits_under_its_named_parent_and_shares_its_hue() -> None:
    for group in SYSTEM_CATEGORIES:
        assert group.key.count(".") == 1
        for child in group.children:
            assert child.key.rsplit(".", 1)[0] == group.key
            assert child.color == group.color
            assert not child.children


def _arb_key(category_key: str) -> str:
    words = [word for part in category_key.split(".")[1:] for word in part.split("_")]
    return "categorySystem" + "".join(word.capitalize() for word in words)


def test_every_category_has_matching_fr_and_en_arb_entries() -> None:
    fr = json.loads((_FRONTEND / "l10n" / "app_fr.arb").read_text(encoding="utf-8"))
    en = json.loads((_FRONTEND / "l10n" / "app_en.arb").read_text(encoding="utf-8"))
    display = (_FRONTEND / "lib" / "core" / "l10n" / "category_display.dart").read_text(
        encoding="utf-8"
    )
    nodes = list(_flatten(SYSTEM_CATEGORIES))

    for node in nodes:
        arb_key = _arb_key(node.key)
        assert fr.get(arb_key) == node.name_fr, node.key
        assert en.get(arb_key) == node.name_en, node.key
        assert f"'{node.key}' =>" in display, node.key
    assert {k for k in fr if k.startswith("categorySystem")} == {
        k for k in en if k.startswith("categorySystem")
    }


def test_reseed_adds_new_entries_without_touching_existing_ones(db_session: Session) -> None:
    """An install seeded before a catalog entry existed gets it at the next boot."""
    seed_categories(db_session)
    # Children before their parent: the foreign key forbids an orphan even mid-transaction.
    for key in ("category.pets.food", "category.pets.vet", "category.health.dentist"):
        db_session.delete(db_session.query(Category).filter_by(name=key).one())
    db_session.flush()
    db_session.delete(db_session.query(Category).filter_by(name="category.pets").one())
    db_session.commit()
    before = {c.name: (c.id, c.parent_id) for c in db_session.query(Category).all()}

    created = seed_categories(db_session)

    after = {c.name: (c.id, c.parent_id) for c in db_session.query(Category).all()}
    assert created == 4
    assert {name: after[name] for name in before} == before
    pets_id = after["category.pets"][0]
    assert after["category.pets.vet"][1] == pets_id
    assert after["category.health.dentist"][1] == after["category.health"][0]


def test_categorization_prompt_offers_the_new_leaves(db_session: Session) -> None:
    seed_categories(db_session)

    offered = leaf_categories(db_session.query(Category).all(), "fr")

    names = {category.name for category in offered}
    assert {"Dentiste", "Péages", "Vétérinaire", "Dons"} <= names
    # Parents are never offered once they have children; Abonnements stays a leaf.
    assert "Animaux" not in names
    assert "Abonnements" in names


def test_seed_creates_system_rows_with_parent_links(db_session: Session) -> None:
    seed_categories(db_session)

    housing = db_session.query(Category).filter_by(name="category.housing").one()
    rent = db_session.query(Category).filter_by(name="category.housing.rent").one()

    assert housing.is_system is True
    assert housing.user_id is None
    assert housing.parent_id is None
    assert rent.parent_id == housing.id
    assert rent.kind == "expense"


def test_seed_is_idempotent(db_session: Session) -> None:
    seed_categories(db_session)
    first_ids = {c.id for c in db_session.query(Category).all()}

    seed_categories(db_session)
    second_ids = {c.id for c in db_session.query(Category).all()}

    assert second_ids == first_ids
    assert len(first_ids) == len(list(_flatten(SYSTEM_CATEGORIES)))


def test_startup_seeds_the_catalog(client: TestClient) -> None:
    """A booted app has the catalog, without anyone having seeded it by hand.

    This is the regression guard for the gap this seeding closed: `seed_categories` existed and
    was tested, but nothing in the running app ever called it, so a real install had zero
    categories and the rule engine had nothing to assign.
    """
    client.post(
        "/api/v1/auth/register",
        json={
            "email": "seed@example.com",
            "password": "correct-horse-battery-staple",
            "display_name": "seed",
            "locale": "fr",
            "currency": "eur",
        },
    )
    token = client.post(
        "/api/v1/auth/login",
        json={"identifier": "seed@example.com", "password": "correct-horse-battery-staple"},
    ).json()["token"]

    body = client.get("/api/v1/categories", headers={"Authorization": f"Bearer {token}"}).json()

    names = {c["name"] for c in body if c["is_system"]}
    assert names == {node.key for node in _flatten(SYSTEM_CATEGORIES)}
    assert "category.other.cash" in names


def test_seed_does_not_touch_user_created_categories(db_session: Session) -> None:
    user_category = Category(
        user_id=make_user(db_session).id,
        parent_id=None,
        name="My custom category",
        kind="expense",
        icon="star",
        color="#000000",
        is_system=False,
    )
    db_session.add(user_category)
    db_session.commit()

    seed_categories(db_session)

    still_present = db_session.query(Category).filter_by(id=user_category.id).one()
    assert still_present.is_system is False
    assert still_present.name == "My custom category"
