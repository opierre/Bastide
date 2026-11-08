"""Tests for exporting rule logos in a pack: the flag, the round trip, and the per-pack cap."""

import base64

import pytest
from fastapi.testclient import TestClient

from app.features.rules.packs import service as service_module
from tests.features.rules.packs.helpers import (
    GROCERIES,
    TRANSIT,
    category_id_for_key,
    entry,
    export_pack,
    import_pack,
    pack,
)
from tests.features.rules.packs.test_logos import _embedded, _logo, _picture, _rules
from tests.features.rules.test_rules import _create_rule, _register


def _with_logos(client: TestClient, headers: dict[str, str]) -> None:
    """Two rules with a logo and one without, through an ordinary import."""
    status_code, body = import_pack(
        client,
        headers,
        pack=pack(
            entry("EPICERIE LUNE", logo=_embedded(_picture(colour=(10, 120, 60)))),
            entry("VELO RAPIDE", TRANSIT, logo=_embedded(_picture("JPEG", (30, 30, 200)))),
            entry("BOULANGERIE DU PORT"),
        ),
    )
    assert status_code == 200
    assert body["logo_count"] == 2


def test_logos_are_left_out_unless_asked_for(client: TestClient) -> None:
    headers, _ = _register(client)
    _with_logos(client, headers)

    body = export_pack(client, headers)

    assert all("logo" not in rule for rule in body["pack"]["rules"])
    assert (body["logo_count"], body["logo_bytes"], body["logos_too_large"]) == (0, 0, False)


def test_an_exported_logo_is_the_stored_png(client: TestClient) -> None:
    headers, _ = _register(client)
    _with_logos(client, headers)
    rules = _rules(client, headers)

    body = export_pack(client, headers, include_logos=True)

    exported = {rule["pattern"]: rule.get("logo") for rule in body["pack"]["rules"]}
    stored = {
        pattern: _logo(client, headers, rules[pattern]["id"])
        for pattern in ("EPICERIE LUNE", "VELO RAPIDE")
    }
    assert exported["BOULANGERIE DU PORT"] is None
    for pattern, image in stored.items():
        assert image is not None
        assert base64.b64decode(exported[pattern]["data"], validate=True) == image
    assert body["logo_count"] == 2
    assert body["logo_bytes"] == sum(len(image) for image in stored.values() if image)
    assert body["logos_too_large"] is False


def test_logos_round_trip_to_a_fresh_profile(client: TestClient) -> None:
    author, _ = _register(client)
    _with_logos(client, author)
    exported = export_pack(client, author, include_logos=True)["pack"]

    friend, _ = _register(client, "basile@example.com")
    status_code, body = import_pack(client, friend, pack=exported)

    assert status_code == 200
    assert (body["created_count"], body["logo_count"], body["logo_failures"]) == (3, 2, [])
    theirs, ours = _rules(client, author), _rules(client, friend)
    for pattern in ("EPICERIE LUNE", "VELO RAPIDE"):
        original = _logo(client, author, theirs[pattern]["id"])
        assert original is not None
        assert _logo(client, friend, ours[pattern]["id"]) == original
    assert ours["BOULANGERIE DU PORT"]["logo_updated_at"] is None


def test_logos_over_the_per_pack_cap_are_all_left_out_and_reported(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    headers, _ = _register(client)
    _with_logos(client, headers)
    monkeypatch.setattr(service_module, "MAX_PACK_LOGO_BYTES", 100)

    body = export_pack(client, headers, include_logos=True)

    assert body["logos_too_large"] is True
    assert body["logo_count"] == 0
    assert body["logo_bytes"] > 100
    assert len(body["pack"]["rules"]) == 3
    assert all("logo" not in rule for rule in body["pack"]["rules"])
    friend, _ = _register(client, "basile@example.com")
    status_code, _ = import_pack(client, friend, pack=body["pack"])
    assert status_code == 200


def test_an_omitted_rules_logo_is_not_exported_or_counted(client: TestClient) -> None:
    headers, _ = _register(client)
    groceries = category_id_for_key(client, headers, GROCERIES)
    regex_rule = _create_rule(client, headers, groceries, match_type="regex", pattern=r"LUNE \d+")
    uploaded = client.put(
        f"/api/v1/rules/{regex_rule['id']}/logo",
        headers=headers,
        files={"file": ("logo.png", _picture(), "image/png")},
    )
    assert uploaded.status_code == 200, uploaded.text

    body = export_pack(client, headers, include_logos=True)

    assert body["pack"]["rules"] == []
    assert [omitted["reason"] for omitted in body["omitted"]] == ["regex"]
    assert (body["logo_count"], body["logo_bytes"]) == (0, 0)


def test_an_export_carries_no_nulls(client: TestClient) -> None:
    """The JSON schema admits no null, so unset optional fields are left out instead."""
    headers, _ = _register(client)
    _with_logos(client, headers)

    exported = export_pack(client, headers, include_logos=True)["pack"]

    assert None not in exported.values()
    assert all(None not in rule.values() for rule in exported["rules"])
