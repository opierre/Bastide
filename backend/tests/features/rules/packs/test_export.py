"""Tests for exporting a user's rules as a portable pack."""

from pathlib import Path

from fastapi.testclient import TestClient

from tests.features.rules.packs.helpers import (
    GROCERIES,
    SALARY,
    TRANSIT,
    category_id_for_key,
    entry,
    export_pack,
    import_pack,
    pack,
)
from tests.features.rules.test_rules import (
    _create_account,
    _create_category,
    _create_rule,
    _insert_transaction,
    _register,
)


def _categorized_labels(client: TestClient, headers: dict[str, str]) -> dict[str, str | None]:
    """Each transaction's label mapped to the i18n key it ended up categorized under."""
    items = client.get("/api/v1/transactions", headers=headers).json()["items"]
    return {
        item["description_clean"]: (item["category"]["name"] if item["category"] else None)
        for item in items
    }


# --- shape ---------------------------------------------------------------------------------


def test_export_emits_a_pack_in_rule_order(client: TestClient) -> None:
    headers, _ = _register(client)
    import_pack(
        client,
        headers,
        pack=pack(entry("CARREFOUR", GROCERIES), entry("SNCF", TRANSIT)),
    )

    body = export_pack(client, headers)

    assert body["pack"]["format_version"] == 1
    assert body["pack"]["locale"] == "fr"
    assert body["omitted"] == []
    assert body["pack"]["rules"] == [
        {
            "field": "description_clean",
            "type": "contains",
            "pattern": "CARREFOUR",
            "category_key": GROCERIES,
            "enabled": True,
            "comment": None,
        },
        {
            "field": "description_clean",
            "type": "contains",
            "pattern": "SNCF",
            "category_key": TRANSIT,
            "enabled": True,
            "comment": None,
        },
    ]


def test_export_carries_no_ids_or_priorities(client: TestClient) -> None:
    headers, _ = _register(client)
    import_pack(client, headers, pack=pack(entry("CARREFOUR", GROCERIES)))

    body = export_pack(client, headers)

    assert set(body["pack"]["rules"][0]) == {
        "field",
        "type",
        "pattern",
        "category_key",
        "enabled",
        "comment",
    }
    assert "user_id" not in body["pack"]


def test_export_names_the_pack_from_the_query_and_falls_back(client: TestClient) -> None:
    headers, _ = _register(client)
    import_pack(client, headers, pack=pack(entry("CARREFOUR", GROCERIES)))

    assert export_pack(client, headers)["pack"]["name"] == "Bastide rules"
    assert export_pack(client, headers, name="Mes règles")["pack"]["name"] == "Mes règles"


def test_export_of_a_user_with_no_rules_is_an_empty_pack(client: TestClient) -> None:
    headers, _ = _register(client)

    body = export_pack(client, headers)

    assert body["pack"]["rules"] == []
    assert body["omitted"] == []


# --- omissions -----------------------------------------------------------------------------


def test_a_regex_rule_is_omitted_and_reported(client: TestClient) -> None:
    headers, _ = _register(client)
    groceries = category_id_for_key(client, headers, GROCERIES)
    _create_rule(client, headers, groceries, priority=1, pattern="CARREFOUR")
    regex_rule = _create_rule(
        client, headers, groceries, priority=2, match_type="regex", pattern=r"SNCF \d{4}"
    )

    body = export_pack(client, headers)

    assert [rule["pattern"] for rule in body["pack"]["rules"]] == ["CARREFOUR"]
    assert body["omitted"] == [
        {"rule_id": regex_rule["id"], "pattern": r"SNCF \d{4}", "reason": "regex"}
    ]


def test_a_rule_on_a_user_defined_category_is_omitted_and_reported(client: TestClient) -> None:
    headers, _ = _register(client)
    groceries = category_id_for_key(client, headers, GROCERIES)
    _create_rule(client, headers, groceries, priority=1, pattern="CARREFOUR")
    own_category = _create_category(client, headers)
    own_rule = _create_rule(client, headers, own_category, priority=2, pattern="MON MAGASIN")

    body = export_pack(client, headers)

    assert [rule["pattern"] for rule in body["pack"]["rules"]] == ["CARREFOUR"]
    assert body["omitted"] == [
        {"rule_id": own_rule["id"], "pattern": "MON MAGASIN", "reason": "user_category"}
    ]


def test_an_exported_pack_reimports_without_being_refused(client: TestClient) -> None:
    """The point of omitting: what export emits must never fail its own importer."""
    headers, _ = _register(client)
    groceries = category_id_for_key(client, headers, GROCERIES)
    own_category = _create_category(client, headers)
    _create_rule(client, headers, groceries, priority=1, pattern="CARREFOUR")
    _create_rule(client, headers, groceries, priority=2, match_type="regex", pattern=r"SNCF \d+")
    _create_rule(client, headers, own_category, priority=3, pattern="MON MAGASIN")

    exported = export_pack(client, headers)
    headers_b, _ = _register(client, "bruno@example.com")
    status_code, body = import_pack(client, headers_b, pack=exported["pack"])

    assert status_code == 200
    assert body["created_count"] == 1
    assert body["unresolved"] == []
    assert len(exported["omitted"]) == 2


# --- enabled_only --------------------------------------------------------------------------


def test_enabled_only_excludes_disabled_rules(client: TestClient) -> None:
    headers, _ = _register(client)
    groceries = category_id_for_key(client, headers, GROCERIES)
    _create_rule(client, headers, groceries, priority=1, pattern="CARREFOUR")
    _create_rule(client, headers, groceries, priority=2, pattern="LIDL", enabled=False)

    everything = export_pack(client, headers)
    enabled = export_pack(client, headers, enabled_only=True)

    assert [rule["pattern"] for rule in everything["pack"]["rules"]] == ["CARREFOUR", "LIDL"]
    assert [rule["pattern"] for rule in enabled["pack"]["rules"]] == ["CARREFOUR"]


def test_export_preserves_the_enabled_flag(client: TestClient) -> None:
    headers, _ = _register(client)
    groceries = category_id_for_key(client, headers, GROCERIES)
    _create_rule(client, headers, groceries, pattern="LIDL", enabled=False)

    body = export_pack(client, headers)

    assert body["pack"]["rules"][0]["enabled"] is False


# --- round trip ----------------------------------------------------------------------------


def test_export_round_trips_to_the_same_categorization_on_a_second_user(
    client: TestClient, tmp_path: Path
) -> None:
    labels = ("PAIEMENT CARREFOUR MARKET", "SNCF CONNECT", "VIREMENT SALAIRE", "MYSTERE")

    headers_a, user_id_a = _register(client, "amelie@example.com")
    account_a = _create_account(client, headers_a)
    for index, label in enumerate(labels):
        _insert_transaction(tmp_path, user_id_a, account_a, label, amount_minor=-100 * (index + 1))
    import_pack(
        client,
        headers_a,
        pack=pack(
            entry("CARREFOUR", GROCERIES),
            entry("SNCF", TRANSIT),
            entry("VIREMENT SALAIRE", SALARY),
        ),
        apply_now=True,
    )

    exported = export_pack(client, headers_a)

    headers_b, user_id_b = _register(client, "bruno@example.com")
    account_b = _create_account(client, headers_b)
    for index, label in enumerate(labels):
        _insert_transaction(tmp_path, user_id_b, account_b, label, amount_minor=-100 * (index + 1))
    import_pack(client, headers_b, pack=exported["pack"], apply_now=True)

    assert _categorized_labels(client, headers_b) == _categorized_labels(client, headers_a)
    assert _categorized_labels(client, headers_b)["MYSTERE"] is None


# --- scoping -------------------------------------------------------------------------------


def test_export_never_leaks_another_users_rules(client: TestClient) -> None:
    headers_a, _ = _register(client, "amelie@example.com")
    import_pack(client, headers_a, pack=pack(entry("CARREFOUR", GROCERIES)))
    headers_b, _ = _register(client, "bruno@example.com")
    import_pack(client, headers_b, pack=pack(entry("SNCF", TRANSIT)))

    body_b = export_pack(client, headers_b)

    assert [rule["pattern"] for rule in body_b["pack"]["rules"]] == ["SNCF"]
    assert body_b["omitted"] == []


def test_export_requires_auth(client: TestClient) -> None:
    assert client.get("/api/v1/rules/packs/export").status_code == 401
