"""Tests for the idempotent, localized system category seed."""

from collections.abc import Iterator

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.seed import SYSTEM_CATEGORIES, CategorySeed, seed_categories
from app.features.categories.models import Category

VALID_KINDS = {"income", "expense", "transfer"}


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
            "display_name": "Seed",
            "locale": "fr",
            "currency": "eur",
        },
    )
    token = client.post(
        "/api/v1/auth/login",
        json={"email": "seed@example.com", "password": "correct-horse-battery-staple"},
    ).json()["token"]

    body = client.get("/api/v1/categories", headers={"Authorization": f"Bearer {token}"}).json()

    names = {c["name"] for c in body if c["is_system"]}
    assert names == {node.key for node in _flatten(SYSTEM_CATEGORIES)}
    assert "category.other.cash" in names


def test_seed_does_not_touch_user_created_categories(db_session: Session) -> None:
    user_category = Category(
        user_id="some-user-id",
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
