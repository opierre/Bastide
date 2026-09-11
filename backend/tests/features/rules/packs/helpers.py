"""Shared builders for the rule pack tests."""

from typing import Any

from fastapi.testclient import TestClient

GROCERIES = "category.food.groceries"
TRANSIT = "category.transport.public_transit"
SALARY = "category.income.salary"


def entry(
    pattern: str,
    category_key: str = GROCERIES,
    *,
    field: str = "description_clean",
    type_: str = "contains",
    **extra: Any,
) -> dict[str, Any]:
    """One pack rule; `type_` avoids shadowing the builtin at the call sites."""
    return {
        "field": field,
        "type": type_,
        "pattern": pattern,
        "category_key": category_key,
        **extra,
    }


def pack(*entries: dict[str, Any], **overrides: Any) -> dict[str, Any]:
    """A minimal valid pack wrapping ``entries``."""
    return {
        "format_version": 1,
        "name": "Test pack",
        "locale": "fr",
        "rules": list(entries),
        **overrides,
    }


def preview(client: TestClient, headers: dict[str, str], **body: Any) -> tuple[int, dict]:
    response = client.post("/api/v1/rules/packs/preview", json=body, headers=headers)
    return response.status_code, response.json()


def import_pack(client: TestClient, headers: dict[str, str], **body: Any) -> tuple[int, dict]:
    response = client.post("/api/v1/rules/packs/import", json=body, headers=headers)
    return response.status_code, response.json()


def export_pack(client: TestClient, headers: dict[str, str], **params: Any) -> dict:
    response = client.get("/api/v1/rules/packs/export", params=params, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def category_id_for_key(client: TestClient, headers: dict[str, str], key: str) -> str:
    """The seeded system category carrying ``key`` — system rows store the i18n key in `name`."""
    categories = client.get("/api/v1/categories", headers=headers).json()
    match = [category for category in categories if category["name"] == key]
    assert match, f"{key} is not in the seeded catalog"
    return match[0]["id"]
