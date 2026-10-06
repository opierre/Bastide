"""Tests for the OFX/QFX parser, canonical normalization, and the import endpoint."""

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.features.imports.canonical import normalize
from app.features.imports.parsers.ofx import OfxParseError, parse, parse_ledger_balance
from tests.api import register as _register

FIXTURES = Path(__file__).resolve().parent.parent.parent / "fixtures" / "imports"

ACCOUNT_PAYLOAD = {
    "name": "Compte courant",
    "type": "checking",
    "institution": "BNP Paribas",
    "opening_balance_minor": 100_000,
}


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
    assert transactions[0].description_raw == "PRLV ABONNEMENT"


def test_parse_keeps_memo_out_of_the_description() -> None:
    transactions = parse((FIXTURES / "sample.qfx").read_bytes())

    assert transactions[0].description_raw == "PRLV ABONNEMENT"
    assert transactions[0].memo == "Abonnement mensuel"


def test_parse_promotes_a_memo_only_record_to_the_description() -> None:
    raw = b"<OFX><STMTTRN><DTPOSTED>20240410<TRNAMT>-8.20<MEMO>Frais de tenue</STMTTRN></OFX>"

    transactions = parse(raw)

    assert transactions[0].description_raw == "Frais de tenue"
    assert transactions[0].memo is None


def test_parse_drops_a_memo_echoing_the_name() -> None:
    raw = (
        b"<OFX><STMTTRN><DTPOSTED>20240410<TRNAMT>-8.20"
        b"<NAME>CARREFOUR<MEMO>CARREFOUR</STMTTRN></OFX>"
    )

    transactions = parse(raw)

    assert transactions[0].description_raw == "CARREFOUR"
    assert transactions[0].memo is None


def test_parse_handles_latin1_encoding() -> None:
    transactions = parse((FIXTURES / "sample_latin1.ofx").read_bytes())

    assert len(transactions) == 1
    assert "CAFÉ DE PARIS ÉTÉ" in transactions[0].description_raw


def test_parse_rejects_non_ofx_file() -> None:
    with pytest.raises(OfxParseError):
        parse((FIXTURES / "not_ofx.txt").read_bytes())


# --- parser: the declared closing balance ----------------------------------------------


def test_parse_ledger_balance_reads_the_declared_closing_balance() -> None:
    declared = parse_ledger_balance((FIXTURES / "sample_sgml.ofx").read_bytes())

    assert declared is not None
    assert declared.amount_minor == 145_750
    assert declared.as_of is not None
    assert declared.as_of.isoformat() == "2024-01-31"


def test_parse_ledger_balance_tolerates_a_missing_dtasof() -> None:
    declared = parse_ledger_balance((FIXTURES / "sample_sgml_no_dtasof.ofx").read_bytes())

    assert declared is not None
    assert declared.amount_minor == 38_000
    assert declared.as_of is None


def test_parse_ledger_balance_returns_none_when_nothing_is_declared() -> None:
    # A statement need not carry one, and an unreadable file must not raise here:
    # the balance is a bonus, the transactions are the job.
    assert parse_ledger_balance((FIXTURES / "sample_xml.ofx").read_bytes()) is None
    assert parse_ledger_balance((FIXTURES / "not_ofx.txt").read_bytes()) is None


def test_normalize_builds_canonical_transaction() -> None:
    raw = parse((FIXTURES / "sample_sgml.ofx").read_bytes())[0]

    canonical = normalize(raw, account_id="acct-1", currency="EUR")

    assert canonical.amount_minor == -4250
    assert canonical.currency == "EUR"
    assert canonical.description_clean == "CARTE ACHAT SUPERMARCHE"
    assert canonical.merchant == "ACHAT SUPERMARCHE"
    assert canonical.dedup_hash


def test_normalize_drops_a_placeholder_memo() -> None:
    # Crédit Agricole ships `<MEMO>.` on every row with no real detail, which would
    # otherwise render as a stray dot in front of the account name.
    raw = b"<OFX><STMTTRN><DTPOSTED>20240410<TRNAMT>-8.20<NAME>CARREFOUR<MEMO>.</STMTTRN></OFX>"

    canonical = normalize(parse(raw)[0], account_id="acct-1", currency="EUR")

    assert canonical.description_clean == "CARREFOUR"
    assert canonical.memo is None


def test_normalize_keeps_a_memo_that_says_something() -> None:
    raw = (
        b"<OFX><STMTTRN><DTPOSTED>20240410<TRNAMT>-8.20"
        b"<NAME>CARREFOUR<MEMO>Retrait  DAB 12</STMTTRN></OFX>"
    )

    canonical = normalize(parse(raw)[0], account_id="acct-1", currency="EUR")

    assert canonical.memo == "Retrait DAB 12"


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

    # The statement declares LEDGERBAL 1457.50, so the account lands on exactly
    # that — the 100 000 typed at creation is corrected away, not added to.
    account_response = client.get(f"/api/v1/accounts/{account_id}", headers=headers)
    assert account_response.json()["balance_minor"] == 145_750


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

    # Reconciled once on the first import; the second only moves the balance by
    # the row it actually adds.
    account_response = client.get(f"/api/v1/accounts/{account_id}", headers=headers)
    assert account_response.json()["balance_minor"] == 145_750 - 1_200


# --- opening-balance reconciliation from LEDGERBAL ---------------------------------------


def test_first_import_derives_the_opening_balance_from_the_declared_balance(
    client: TestClient,
) -> None:
    """The figure typed at creation is a guess; the statement knows the answer.

    The account is opened with 1 000.00 — what a user reads off their banking app
    today — while the statement says it closed January at 1 457.50 after +1 457.50
    of movement. The opening balance is worked back to 0, which is what the account
    really held before its first transaction.
    """
    headers = _register(client)
    account_id = _create_account(client, headers)

    _upload(client, headers, account_id, FIXTURES / "sample_sgml.ofx", "sample.ofx")

    account = client.get(f"/api/v1/accounts/{account_id}", headers=headers).json()
    assert account["opening_balance_minor"] == 0
    assert account["balance_minor"] == 145_750


def test_reconciliation_falls_back_to_the_last_booked_date_without_dtasof(
    client: TestClient,
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)

    _upload(client, headers, account_id, FIXTURES / "sample_sgml_no_dtasof.ofx", "feb.ofx")

    # 380.00 declared, 80.00 of movement in the file → it opened at 300.00.
    account = client.get(f"/api/v1/accounts/{account_id}", headers=headers).json()
    assert account["opening_balance_minor"] == 30_000
    assert account["balance_minor"] == 38_000


def test_a_later_statement_does_not_re_derive_the_opening_balance(client: TestClient) -> None:
    """Once there is history, the ledger is what we trust.

    The February statement declares 2 000.00, which does not follow from the rows
    we hold — the sign of a gap the user never imported. Re-deriving from it would
    move that gap into the opening balance and silently rewrite January.
    """
    headers = _register(client)
    account_id = _create_account(client, headers)
    _upload(client, headers, account_id, FIXTURES / "sample_sgml.ofx", "jan.ofx")

    response = _upload(
        client, headers, account_id, FIXTURES / "sample_sgml_later_month.ofx", "feb.ofx"
    )

    account = client.get(f"/api/v1/accounts/{account_id}", headers=headers).json()
    assert account["opening_balance_minor"] == 0
    assert account["balance_minor"] == 145_750 - 5_000

    # The gap isn't silently absorbed — it's surfaced on the batch instead: the
    # bank says 2 000.00 as of Feb 29, the ledger implies 1 407.50.
    body = response.json()
    assert body["balance_mismatch_minor"] == 200_000 - (145_750 - 5_000)
    assert body["balance_mismatch_as_of"] == "2024-02-29"


def test_a_matching_later_statement_reports_no_mismatch(client: TestClient) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    _upload(client, headers, account_id, FIXTURES / "sample_sgml.ofx", "jan.ofx")

    response = _upload(
        client, headers, account_id, FIXTURES / "sample_sgml_second_matching.ofx", "feb.ofx"
    )

    assert response.json()["balance_mismatch_minor"] is None
    assert response.json()["balance_mismatch_as_of"] is None


def test_first_import_never_reports_a_mismatch(client: TestClient) -> None:
    """The first import derives the opening balance from LEDGERBAL; nothing to compare yet."""
    headers = _register(client)
    account_id = _create_account(client, headers)

    response = _upload(client, headers, account_id, FIXTURES / "sample_sgml.ofx", "jan.ofx")

    assert response.json()["balance_mismatch_minor"] is None
    assert response.json()["balance_mismatch_as_of"] is None


def test_a_statement_declaring_no_balance_keeps_the_typed_opening_balance(
    client: TestClient,
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)

    _upload(client, headers, account_id, FIXTURES / "sample_xml.ofx", "sample.ofx")

    account = client.get(f"/api/v1/accounts/{account_id}", headers=headers).json()
    assert account["opening_balance_minor"] == 100_000
    assert account["balance_minor"] == 100_000 - 1_990 + 7_500


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
