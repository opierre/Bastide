"""Tests for the French bank-code directory and its lookup endpoint."""

import pytest
from fastapi.testclient import TestClient

from app.features.banks.directory import normalize_bank_code, resolve_bank_name


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
    return {"Authorization": f"Bearer {response.json()['token']}"}


@pytest.mark.parametrize(
    ("code", "expected"),
    [
        ("30004", "BNP Paribas"),
        ("30003", "Société Générale"),
        ("20041", "La Banque Postale"),
        ("40618", "Boursorama"),
        ("17515", "Caisse d'Épargne"),
        ("10207", "Banque Populaire"),
        ("10278", "Crédit Mutuel"),
    ],
)
def test_resolve_bank_name_reads_the_exact_table(code: str, expected: str) -> None:
    assert resolve_bank_name(code) == expected


@pytest.mark.parametrize("code", ["13306", "18206", "16806", "30006"])
def test_resolve_bank_name_recognizes_credit_agricole_regional_codes(code: str) -> None:
    """Regional banks aren't listed one by one — their 1xxxx…06 pattern is."""
    assert resolve_bank_name(code) == "Crédit Agricole"


def test_resolve_bank_name_reads_the_code_out_of_a_longer_bankid() -> None:
    # Banks emit BANKID as the bank code, as bank code + branch, or as a RIB.
    assert resolve_bank_name("1330600001") == "Crédit Agricole"
    assert resolve_bank_name("30004 00001 12345678901") == "BNP Paribas"


def test_resolve_bank_name_returns_none_for_unknown_or_unusable_codes() -> None:
    assert resolve_bank_name("99999") is None
    assert resolve_bank_name("1234") is None
    assert resolve_bank_name("") is None
    assert resolve_bank_name("BOURSORAMA") is None


def test_normalize_bank_code_keeps_the_leading_five_digits() -> None:
    assert normalize_bank_code("30004") == "30004"
    assert normalize_bank_code("30004 00001") == "30004"
    assert normalize_bank_code("300") is None


def test_lookup_bank_returns_the_resolved_bank(client: TestClient) -> None:
    headers = _register(client)

    response = client.get("/api/v1/banks", params={"bank_code": "13306"}, headers=headers)

    assert response.status_code == 200
    assert response.json() == [{"bank_code": "13306", "name": "Crédit Agricole"}]


def test_lookup_bank_returns_empty_for_an_unknown_code(client: TestClient) -> None:
    """A miss is an ordinary outcome of a guess, not a client error."""
    headers = _register(client)

    response = client.get("/api/v1/banks", params={"bank_code": "99999"}, headers=headers)

    assert response.status_code == 200
    assert response.json() == []


def test_lookup_bank_requires_authentication(client: TestClient) -> None:
    response = client.get("/api/v1/banks", params={"bank_code": "30004"})

    assert response.status_code == 401
