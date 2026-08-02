"""Tests for the template-driven CSV parser, csv_template CRUD, preview, and CSV import."""

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.features.imports.parsers.csv import CsvParseError, CsvTemplateConfig, parse

FIXTURES = Path(__file__).resolve().parent.parent.parent / "fixtures" / "imports"

ACCOUNT_PAYLOAD = {
    "name": "Compte courant",
    "type": "checking",
    "institution": "Ma Banque",
    "opening_balance_minor": 100_000,
}

SIGNED_TEMPLATE_PAYLOAD = {
    "bank_name": "Ma Banque",
    "delimiter": ";",
    "encoding": "utf-8",
    "date_format": "%d/%m/%Y",
    "decimal_separator": ",",
    "amount_strategy": "signed",
    "column_map": {"booked_date": "Date", "description": "Libelle", "amount": "Montant"},
    "header_offset": 0,
}

DEBIT_CREDIT_TEMPLATE_PAYLOAD = {
    "bank_name": "Ma Banque",
    "delimiter": ";",
    "encoding": "utf-8",
    "date_format": "%d/%m/%Y",
    "decimal_separator": ",",
    "amount_strategy": "debit_credit",
    "column_map": {
        "booked_date": "Date",
        "description": "Libelle",
        "debit": "Debit",
        "credit": "Credit",
    },
    "header_offset": 0,
}


def _signed_config(**overrides: object) -> CsvTemplateConfig:
    payload = {**SIGNED_TEMPLATE_PAYLOAD, **overrides}
    return CsvTemplateConfig(
        delimiter=payload["delimiter"],
        encoding=payload["encoding"],
        date_format=payload["date_format"],
        decimal_separator=payload["decimal_separator"],
        amount_strategy=payload["amount_strategy"],
        column_map=payload["column_map"],
        header_offset=payload["header_offset"],
    )


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


def _create_template(
    client: TestClient, headers: dict[str, str], payload: dict[str, object]
) -> str:
    response = client.post("/api/v1/csv-templates", json=payload, headers=headers)
    assert response.status_code == 201, response.json()
    return response.json()["id"]


def _upload(
    client: TestClient,
    headers: dict[str, str],
    account_id: str,
    csv_template_id: str,
    path: Path,
    filename: str,
):
    with path.open("rb") as fh:
        return client.post(
            "/api/v1/imports",
            headers=headers,
            data={"account_id": account_id, "csv_template_id": csv_template_id},
            files={"file": (filename, fh, "text/csv")},
        )


# --- parser: delimiter, comma decimal, dd/mm/yyyy, debit/credit, Latin-1, header offset -----


def test_parse_signed_amounts() -> None:
    transactions = parse((FIXTURES / "sample_signed.csv").read_bytes(), _signed_config())

    assert len(transactions) == 2
    assert transactions[0].amount_minor == -4250
    assert transactions[0].booked_date.isoformat() == "2024-01-05"
    assert transactions[0].description_raw == "CARTE ACHAT SUPERMARCHE"
    assert transactions[1].amount_minor == 150_000


def test_parse_debit_credit_columns() -> None:
    config = _signed_config(
        amount_strategy="debit_credit",
        column_map=DEBIT_CREDIT_TEMPLATE_PAYLOAD["column_map"],
    )
    transactions = parse((FIXTURES / "sample_debit_credit.csv").read_bytes(), config)

    assert len(transactions) == 2
    assert transactions[0].amount_minor == -4250
    assert transactions[1].amount_minor == 150_000


def test_parse_handles_latin1_encoding() -> None:
    config = _signed_config(encoding="latin-1")
    transactions = parse((FIXTURES / "sample_latin1.csv").read_bytes(), config)

    assert len(transactions) == 1
    assert "CAFÉ DE PARIS ÉTÉ" in transactions[0].description_raw


def test_parse_applies_header_offset() -> None:
    config = _signed_config(header_offset=2)
    transactions = parse((FIXTURES / "sample_header_offset.csv").read_bytes(), config)

    assert len(transactions) == 1
    assert transactions[0].amount_minor == -4250


def test_parse_rejects_unmapped_column() -> None:
    config = _signed_config(column_map={"booked_date": "Date", "description": "Libelle"})
    with pytest.raises(CsvParseError):
        parse((FIXTURES / "sample_signed.csv").read_bytes(), config)


def test_parse_rejects_unknown_column_name() -> None:
    config = _signed_config(
        column_map={"booked_date": "Date", "description": "Libelle", "amount": "DoesNotExist"}
    )
    with pytest.raises(CsvParseError):
        parse((FIXTURES / "sample_signed.csv").read_bytes(), config)


# --- csv_template CRUD ----------------------------------------------------------------------


def test_create_and_list_csv_template(client: TestClient) -> None:
    headers = _register(client)

    template_id = _create_template(client, headers, SIGNED_TEMPLATE_PAYLOAD)

    response = client.get("/api/v1/csv-templates", headers=headers)
    assert response.status_code == 200
    templates = response.json()
    assert len(templates) == 1
    assert templates[0]["id"] == template_id
    assert templates[0]["bank_name"] == "Ma Banque"
    assert templates[0]["header_offset"] == 0


def test_create_csv_template_rejects_missing_required_column(client: TestClient) -> None:
    headers = _register(client)
    payload = {
        **SIGNED_TEMPLATE_PAYLOAD,
        "column_map": {"booked_date": "Date", "description": "Libelle"},
    }

    response = client.post("/api/v1/csv-templates", json=payload, headers=headers)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "CSV_TEMPLATE_INVALID"


def test_create_csv_template_rejects_bad_date_format(client: TestClient) -> None:
    headers = _register(client)
    payload = {**SIGNED_TEMPLATE_PAYLOAD, "date_format": "%Q/%Y"}

    response = client.post("/api/v1/csv-templates", json=payload, headers=headers)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "CSV_TEMPLATE_INVALID"


# --- preview: parses without importing ----------------------------------------------------


def test_preview_returns_sample_rows_without_importing(client: TestClient) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)

    with (FIXTURES / "sample_signed.csv").open("rb") as fh:
        response = client.post(
            "/api/v1/csv-templates/preview",
            headers=headers,
            data={
                "bank_name": SIGNED_TEMPLATE_PAYLOAD["bank_name"],
                "delimiter": SIGNED_TEMPLATE_PAYLOAD["delimiter"],
                "encoding": SIGNED_TEMPLATE_PAYLOAD["encoding"],
                "date_format": SIGNED_TEMPLATE_PAYLOAD["date_format"],
                "decimal_separator": SIGNED_TEMPLATE_PAYLOAD["decimal_separator"],
                "amount_strategy": SIGNED_TEMPLATE_PAYLOAD["amount_strategy"],
                "column_map": '{"booked_date": "Date", "description": "Libelle", '
                '"amount": "Montant"}',
                "header_offset": "0",
            },
            files={"file": ("sample.csv", fh, "text/csv")},
        )

    assert response.status_code == 200
    rows = response.json()
    assert len(rows) == 2
    assert rows[0]["amount_minor"] == -4250

    # Nothing was persisted: no batches, no accounts touched.
    templates_response = client.get("/api/v1/csv-templates", headers=headers)
    assert templates_response.json() == []
    imports_response = client.get("/api/v1/imports", headers=headers)
    assert imports_response.json() == []
    account_response = client.get(f"/api/v1/accounts/{account_id}", headers=headers)
    assert account_response.json()["balance_minor"] == 100_000


# --- CSV import endpoint: persistence, dedup, atomic balance update ------------------------


def test_import_csv_creates_batch_and_updates_balance(client: TestClient) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    template_id = _create_template(client, headers, SIGNED_TEMPLATE_PAYLOAD)

    response = _upload(
        client, headers, account_id, template_id, FIXTURES / "sample_signed.csv", "sample.csv"
    )

    assert response.status_code == 201
    body = response.json()
    assert body["source_format"] == "csv"
    assert body["status"] == "success"
    assert body["transaction_count"] == 2
    assert body["new_count"] == 2
    assert body["duplicate_count"] == 0

    account_response = client.get(f"/api/v1/accounts/{account_id}", headers=headers)
    assert account_response.json()["balance_minor"] == 100_000 - 4_250 + 150_000


def test_import_csv_with_debit_credit_columns(client: TestClient) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    template_id = _create_template(client, headers, DEBIT_CREDIT_TEMPLATE_PAYLOAD)

    response = _upload(
        client,
        headers,
        account_id,
        template_id,
        FIXTURES / "sample_debit_credit.csv",
        "sample.csv",
    )

    assert response.status_code == 201
    body = response.json()
    assert body["new_count"] == 2
    account_response = client.get(f"/api/v1/accounts/{account_id}", headers=headers)
    assert account_response.json()["balance_minor"] == 100_000 - 4_250 + 150_000


def test_reimporting_identical_csv_inserts_nothing(client: TestClient) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    template_id = _create_template(client, headers, SIGNED_TEMPLATE_PAYLOAD)

    first = _upload(
        client, headers, account_id, template_id, FIXTURES / "sample_signed.csv", "sample.csv"
    )
    balance_after_first = client.get(f"/api/v1/accounts/{account_id}", headers=headers).json()[
        "balance_minor"
    ]

    second = _upload(
        client, headers, account_id, template_id, FIXTURES / "sample_signed.csv", "sample.csv"
    )
    balance_after_second = client.get(f"/api/v1/accounts/{account_id}", headers=headers).json()[
        "balance_minor"
    ]

    assert second.status_code == 201
    assert second.json()["id"] == first.json()["id"]
    assert balance_after_second == balance_after_first


def test_reimport_csv_with_overlapping_row_marks_duplicate(client: TestClient) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    template_id = _create_template(client, headers, SIGNED_TEMPLATE_PAYLOAD)
    _upload(client, headers, account_id, template_id, FIXTURES / "sample_signed.csv", "s1.csv")

    response = _upload(
        client,
        headers,
        account_id,
        template_id,
        FIXTURES / "sample_signed_overlap.csv",
        "s2.csv",
    )

    assert response.status_code == 201
    body = response.json()
    assert body["transaction_count"] == 2
    assert body["new_count"] == 1
    assert body["duplicate_count"] == 1

    account_response = client.get(f"/api/v1/accounts/{account_id}", headers=headers)
    assert account_response.json()["balance_minor"] == 100_000 - 4_250 + 150_000 - 1_200


def test_import_csv_requires_existing_template(client: TestClient) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)

    response = _upload(
        client,
        headers,
        account_id,
        "does-not-exist",
        FIXTURES / "sample_signed.csv",
        "sample.csv",
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "CSV_TEMPLATE_NOT_FOUND"
