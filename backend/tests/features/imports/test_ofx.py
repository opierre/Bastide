"""Tests for the OFX/QFX parser, canonical normalization, and the import endpoint."""

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.features.imports.canonical import normalize
from app.features.imports.parsers.ofx import OfxParseError, parse

FIXTURES = Path(__file__).resolve().parent.parent.parent / "fixtures" / "imports"

ACCOUNT_PAYLOAD = {
    "name": "Compte courant",
    "type": "checking",
    "institution": "BNP Paribas",
    "opening_balance_minor": 100_000,
}


def _register(client: TestClient, email: str = "amelie@example.com") -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "correct-horse-battery-staple",
            "display_name": "Amelie",
            "locale": "fr",
            "currency": "eur",
        },
    )
    token = response.json()["token"]
    return {"Authorization": f"Bearer {token}"}


def _create_account(client: TestClient, headers: dict[str, str]) -> str:
    response = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers)
    return response.json()["id"]


def _upload(
    client: TestClient, headers: dict[str, str], account_id: str, path: Path, filename: str
):
    with path.open("rb") as fh:
        return client.post(
            "/api/v1/imports",
            headers=headers,
            data={"account_id": account_id},
            files={"file": (filename, fh, "application/octet-stream")},
        )


# --- parser: OFX 1.x SGML, OFX 2.x XML, QFX, Latin-1 ------------------------------------


def test_parse_ofx_sgml_extracts_transactions() -> None:
    transactions = parse((FIXTURES / "sample_sgml.ofx").read_bytes())

    assert len(transactions) == 2
    assert transactions[0].amount_minor == -4250
    assert transactions[0].fitid == "2024010500001"
    assert transactions[0].booked_date.isoformat() == "2024-01-05"
    assert transactions[1].amount_minor == 150_000


def test_parse_ofx_xml_extracts_transactions() -> None:
    transactions = parse((FIXTURES / "sample_xml.ofx").read_bytes())

    assert len(transactions) == 2
    assert transactions[0].amount_minor == -1990
    assert transactions[1].amount_minor == 7500


def test_parse_qfx_tolerates_quicken_extras() -> None:
    transactions = parse((FIXTURES / "sample.qfx").read_bytes())

    assert len(transactions) == 1
    assert transactions[0].amount_minor == -820
    assert transactions[0].description_raw == "PRLV ABONNEMENT Abonnement mensuel"


def test_parse_handles_latin1_encoding() -> None:
    transactions = parse((FIXTURES / "sample_latin1.ofx").read_bytes())

    assert len(transactions) == 1
    assert "CAFÉ DE PARIS ÉTÉ" in transactions[0].description_raw


def test_parse_rejects_non_ofx_file() -> None:
    with pytest.raises(OfxParseError):
        parse((FIXTURES / "not_ofx.txt").read_bytes())


def test_normalize_builds_canonical_transaction() -> None:
    raw = parse((FIXTURES / "sample_sgml.ofx").read_bytes())[0]

    canonical = normalize(raw, account_id="acct-1", currency="EUR")

    assert canonical.amount_minor == -4250
    assert canonical.currency == "EUR"
    assert canonical.description_clean == "CARTE ACHAT SUPERMARCHE"
    assert canonical.merchant == "ACHAT SUPERMARCHE"
    assert canonical.dedup_hash


# --- import endpoint: persistence, dedup, idempotency, failure --------------------------


def test_import_ofx_creates_batch_and_updates_balance(client: TestClient) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)

    response = _upload(client, headers, account_id, FIXTURES / "sample_sgml.ofx", "sample.ofx")

    assert response.status_code == 201
    body = response.json()
    assert body["source_format"] == "ofx"
    assert body["status"] == "success"
    assert body["transaction_count"] == 2
    assert body["new_count"] == 2
    assert body["duplicate_count"] == 0
    assert body["period_start"] == "2024-01-05"
    assert body["period_end"] == "2024-01-15"

    account_response = client.get(f"/api/v1/accounts/{account_id}", headers=headers)
    assert account_response.json()["balance_minor"] == 100_000 - 4_250 + 150_000


def test_reimporting_identical_file_inserts_nothing(client: TestClient) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)

    first = _upload(client, headers, account_id, FIXTURES / "sample_sgml.ofx", "sample.ofx")
    balance_after_first = client.get(f"/api/v1/accounts/{account_id}", headers=headers).json()[
        "balance_minor"
    ]

    second = _upload(client, headers, account_id, FIXTURES / "sample_sgml.ofx", "sample.ofx")
    balance_after_second = client.get(f"/api/v1/accounts/{account_id}", headers=headers).json()[
        "balance_minor"
    ]

    assert second.status_code == 201
    assert second.json()["id"] == first.json()["id"]
    assert balance_after_second == balance_after_first


def test_reimport_with_overlapping_fitid_marks_duplicate(client: TestClient) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    _upload(client, headers, account_id, FIXTURES / "sample_sgml.ofx", "sample.ofx")

    response = _upload(
        client, headers, account_id, FIXTURES / "sample_sgml_overlap.ofx", "overlap.ofx"
    )

    assert response.status_code == 201
    body = response.json()
    assert body["transaction_count"] == 2
    assert body["new_count"] == 1
    assert body["duplicate_count"] == 1

    account_response = client.get(f"/api/v1/accounts/{account_id}", headers=headers)
    assert account_response.json()["balance_minor"] == 100_000 - 4_250 + 150_000 - 1_200


def test_import_invalid_file_records_failed_batch_with_no_rows(client: TestClient) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)

    response = _upload(client, headers, account_id, FIXTURES / "not_ofx.txt", "not_ofx.txt")

    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "failed"
    assert body["error_message"]
    assert body["transaction_count"] == 0
    assert body["new_count"] == 0
    assert body["duplicate_count"] == 0

    account_response = client.get(f"/api/v1/accounts/{account_id}", headers=headers)
    assert account_response.json()["balance_minor"] == 100_000


def test_import_requires_existing_account(client: TestClient) -> None:
    headers = _register(client)

    response = _upload(
        client, headers, "does-not-exist", FIXTURES / "sample_sgml.ofx", "sample.ofx"
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "ACCOUNT_NOT_FOUND"


def test_import_requires_auth(client: TestClient) -> None:
    with (FIXTURES / "sample_sgml.ofx").open("rb") as fh:
        response = client.post(
            "/api/v1/imports",
            data={"account_id": "whatever"},
            files={"file": ("sample.ofx", fh, "application/octet-stream")},
        )

    assert response.status_code == 401
