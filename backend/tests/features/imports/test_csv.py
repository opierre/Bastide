"""Tests for the template-driven CSV parser: delimiter, decimals, dates, encoding, layout."""

from pathlib import Path

import pytest

from app.features.imports.parsers.csv import CsvParseError, CsvTemplateConfig, parse

FIXTURES = Path(__file__).resolve().parent.parent.parent / "fixtures" / "imports"

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
