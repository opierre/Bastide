"""Tests for binding a pack's `category_key`s to the importing user's categories."""

from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker

from app.features.categories.models import Category
from tests.features.rules.packs.helpers import (
    GROCERIES,
    SALARY,
    category_id_for_key,
    entry,
    import_pack,
    pack,
    preview,
)
from tests.features.rules.test_rules import _register


def _count_categories(tmp_path: Path) -> int:
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}", connect_args={"check_same_thread": False}
    )
    session = sessionmaker(bind=engine)()
    count = len(list(session.scalars(select(Category))))
    session.close()
    return count


def test_a_system_key_resolves(client: TestClient) -> None:
    headers, _ = _register(client)

    status_code, body = import_pack(client, headers, pack=pack(entry("CARREFOUR", GROCERIES)))

    assert status_code == 200
    assert body["created_count"] == 1
    assert body["unresolved"] == []
    rule = client.get("/api/v1/rules", headers=headers).json()[0]
    assert rule["category_id"] == category_id_for_key(client, headers, GROCERIES)


def test_an_unknown_key_is_reported_and_its_rule_skipped(client: TestClient) -> None:
    headers, _ = _register(client)
    payload = pack(
        entry("CARREFOUR", GROCERIES),
        entry("MYSTERE", "category.does_not_exist"),
        entry("VIREMENT SALAIRE", SALARY),
    )

    _, body = import_pack(client, headers, pack=payload)

    assert body["created_count"] == 2
    assert body["unresolved"] == ["category.does_not_exist"]


def test_an_unknown_key_never_creates_a_category(client: TestClient, tmp_path: Path) -> None:
    headers, _ = _register(client)
    before = _count_categories(tmp_path)

    _, body = import_pack(client, headers, pack=pack(entry("MYSTERE", "category.invented")))

    assert body["created_count"] == 0
    assert body["unresolved"] == ["category.invented"]
    assert _count_categories(tmp_path) == before


def test_a_repeated_unknown_key_is_reported_once(client: TestClient) -> None:
    headers, _ = _register(client)
    payload = pack(
        entry("UN", "category.invented"),
        entry("DEUX", "category.invented"),
        entry("TROIS", "category.other_invention"),
    )

    _, body = import_pack(client, headers, pack=payload)

    assert body["unresolved"] == ["category.invented", "category.other_invention"]


def test_resolution_never_binds_another_users_category(client: TestClient) -> None:
    """A user-defined category is unreachable from a pack — for its owner and for anyone else."""
    headers_b, _ = _register(client, "bruno@example.com")
    bruno_category = client.post(
        "/api/v1/categories",
        json={
            "name": "category.food.groceries",
            "kind": "expense",
            "icon": "x",
            "color": "#111111",
        },
        headers=headers_b,
    ).json()

    headers_a, _ = _register(client, "amelie@example.com")
    _, body = import_pack(client, headers_a, pack=pack(entry("CARREFOUR", GROCERIES)))

    rule = client.get("/api/v1/rules", headers=headers_a).json()[0]
    assert body["created_count"] == 1
    assert rule["category_id"] != bruno_category["id"]
    assert rule["category_id"] == category_id_for_key(client, headers_a, GROCERIES)


def test_a_user_defined_category_name_is_not_a_resolvable_key(client: TestClient) -> None:
    """`categories.name` holds an i18n key only for system rows; user text must not resolve."""
    headers, _ = _register(client)
    client.post(
        "/api/v1/categories",
        json={"name": "category.my.custom", "kind": "expense", "icon": "x", "color": "#111111"},
        headers=headers,
    )

    _, body = import_pack(client, headers, pack=pack(entry("CARREFOUR", "category.my.custom")))

    assert body["created_count"] == 0
    assert body["unresolved"] == ["category.my.custom"]


def test_preview_reports_the_same_unresolved_keys_as_the_import(client: TestClient) -> None:
    headers, _ = _register(client)
    payload = pack(entry("CARREFOUR", GROCERIES), entry("MYSTERE", "category.invented"))

    _, previewed = preview(client, headers, pack=payload)
    _, imported = import_pack(client, headers, pack=payload)

    assert previewed["unresolved"] == imported["unresolved"] == ["category.invented"]
    assert previewed["new_count"] == imported["created_count"] == 1
