"""Tests for the rule pack wire format: what a pack may contain, and what it may not."""

from fastapi.testclient import TestClient

from tests.features.rules.packs.helpers import entry, pack, preview
from tests.features.rules.test_rules import _register


def test_a_valid_pack_parses(client: TestClient) -> None:
    headers, _ = _register(client)

    status_code, body = preview(client, headers, pack=pack(entry("CARREFOUR")))

    assert status_code == 200
    assert body["name"] == "Test pack"
    assert body["total"] == 1


def test_a_pack_may_carry_optional_metadata(client: TestClient) -> None:
    headers, _ = _register(client)
    payload = pack(
        entry("CARREFOUR", enabled=False, comment="Pour les tests"),
        description="Un pack de test.",
        source_url="https://example.com/pack.json",
    )

    status_code, _ = preview(client, headers, pack=payload)

    assert status_code == 200


# --- format_version ----------------------------------------------------------------------


def test_format_version_zero_is_rejected(client: TestClient) -> None:
    headers, _ = _register(client)

    status_code, body = preview(client, headers, pack=pack(entry("CARREFOUR"), format_version=0))

    assert status_code == 422
    assert "format_version 1" in str(body)


def test_format_version_two_is_rejected_naming_the_supported_version(client: TestClient) -> None:
    headers, _ = _register(client)

    status_code, body = preview(client, headers, pack=pack(entry("CARREFOUR"), format_version=2))

    assert status_code == 422
    assert "Unsupported rule pack format_version 2" in str(body)
    assert "format_version 1" in str(body)


def test_a_missing_format_version_is_rejected(client: TestClient) -> None:
    headers, _ = _register(client)
    payload = pack(entry("CARREFOUR"))
    del payload["format_version"]

    status_code, _ = preview(client, headers, pack=payload)

    assert status_code == 422


# --- refused match types -------------------------------------------------------------------


def test_a_regex_entry_is_rejected(client: TestClient) -> None:
    headers, _ = _register(client)

    status_code, body = preview(
        client, headers, pack=pack(entry(r"CARREFOUR \d{4}", type_="regex"))
    )

    assert status_code == 422
    assert "not allowed in a rule pack" in str(body)


def test_the_permitted_match_types_are_accepted(client: TestClient) -> None:
    headers, _ = _register(client)
    payload = pack(
        entry("CARREFOUR", type_="contains"),
        entry("SNCF", type_="equals"),
        entry("100000:", field="amount", type_="range"),
    )

    status_code, body = preview(client, headers, pack=payload)

    assert status_code == 200
    assert body["total"] == 3


# --- size limits ---------------------------------------------------------------------------


def test_a_pattern_over_255_characters_is_rejected(client: TestClient) -> None:
    headers, _ = _register(client)

    status_code, _ = preview(client, headers, pack=pack(entry("X" * 256)))

    assert status_code == 422


def test_a_pattern_of_exactly_255_characters_is_accepted(client: TestClient) -> None:
    headers, _ = _register(client)

    status_code, _ = preview(client, headers, pack=pack(entry("X" * 255)))

    assert status_code == 200


def test_a_pack_over_1000_entries_is_rejected(client: TestClient) -> None:
    headers, _ = _register(client)
    payload = pack(*[entry(f"MARCHAND {index}") for index in range(1001)])

    status_code, _ = preview(client, headers, pack=payload)

    assert status_code == 422


# --- unknown fields and malformed keys -----------------------------------------------------


def test_an_unknown_entry_field_is_rejected(client: TestClient) -> None:
    headers, _ = _register(client)

    status_code, _ = preview(client, headers, pack=pack(entry("CARREFOUR", priority=1)))

    assert status_code == 422


def test_a_malformed_category_key_is_rejected(client: TestClient) -> None:
    headers, _ = _register(client)

    status_code, _ = preview(client, headers, pack=pack(entry("CARREFOUR", "Courses")))

    assert status_code == 422


# --- the request envelope ------------------------------------------------------------------


def test_a_request_with_neither_pack_nor_builtin_id_is_rejected(client: TestClient) -> None:
    headers, _ = _register(client)

    status_code, _ = preview(client, headers)

    assert status_code == 422


def test_a_request_with_both_pack_and_builtin_id_is_rejected(client: TestClient) -> None:
    headers, _ = _register(client)

    status_code, _ = preview(
        client, headers, pack=pack(entry("CARREFOUR")), builtin_id="fr-common.v1"
    )

    assert status_code == 422


def test_an_unknown_builtin_id_is_a_404(client: TestClient) -> None:
    headers, _ = _register(client)

    status_code, body = preview(client, headers, builtin_id="nope.v9")

    assert status_code == 404
    assert body["error"]["code"] == "RULE_PACK_NOT_FOUND"


def test_pack_preview_requires_auth(client: TestClient) -> None:
    response = client.post("/api/v1/rules/packs/preview", json={"builtin_id": "fr-common.v1"})

    assert response.status_code == 401
