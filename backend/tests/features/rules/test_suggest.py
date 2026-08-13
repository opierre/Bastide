"""Tests for the rule pattern suggested from a transaction: the pure function and its endpoint."""

from datetime import date
from pathlib import Path

from fastapi.testclient import TestClient

from app.features.rules.suggest import MAX_PATTERN_LENGTH, suggest_rule
from app.features.transactions.models import Transaction
from tests.features.rules.test_rules import (
    _create_account,
    _insert_transaction,
    _register,
)


def _transaction(description_clean: str, merchant: str | None = None) -> Transaction:
    """A detached Transaction carrying only what the suggester reads."""
    return Transaction(
        account_id="account-1",
        import_batch_id="batch-1",
        booked_date=date(2026, 5, 14),
        amount_minor=-1250,
        currency="EUR",
        description_raw=description_clean,
        description_clean=description_clean,
        merchant=merchant,
        categorization_source="uncategorized",
        needs_review=True,
        dedup_hash="dedup-1",
    )


# --- merchant present ----------------------------------------------------------------------


def test_merchant_present_suggests_equals_on_merchant() -> None:
    transaction = _transaction("CB CARREFOUR MARKET PARIS 15", merchant="CARREFOUR MARKET PARIS 15")

    suggestion = suggest_rule(transaction)

    assert suggestion.match_field == "merchant"
    assert suggestion.match_type == "equals"
    assert suggestion.pattern == "CARREFOUR MARKET PARIS 15"


def test_blank_merchant_falls_back_to_the_description() -> None:
    transaction = _transaction("PRLV SEPA ASSUR MAIF", merchant="   ")

    suggestion = suggest_rule(transaction)

    assert suggestion.match_field == "description_clean"
    assert suggestion.pattern == "ASSUR MAIF"


def test_long_merchant_is_capped_to_the_pattern_limit() -> None:
    merchant = "A" * (MAX_PATTERN_LENGTH + 20)

    suggestion = suggest_rule(_transaction(merchant, merchant=merchant))

    assert len(suggestion.pattern) == MAX_PATTERN_LENGTH


# --- merchant absent ----------------------------------------------------------------------


def test_merchant_absent_suggests_contains_on_a_cleaned_token_run() -> None:
    transaction = _transaction("PRLV SEPA CAISSE LOC EPARGNE")

    suggestion = suggest_rule(transaction)

    assert suggestion.match_field == "description_clean"
    assert suggestion.match_type == "contains"
    assert suggestion.pattern == "CAISSE LOC EPARGNE"


def test_dates_are_stripped() -> None:
    transaction = _transaction("PAIEMENT PAR CARTE 12/05 ELECTRICITE VERTE 14/05/2026")

    assert suggest_rule(transaction).pattern == "ELECTRICITE VERTE"


def test_card_sequence_digits_are_stripped() -> None:
    transaction = _transaction("CB 4979 SNCF CONNECT")

    assert suggest_rule(transaction).pattern == "SNCF CONNECT"


def test_reference_numbers_are_stripped() -> None:
    transaction = _transaction("VIR SEPA RECU NOVATECH SARL REF:20260514001")

    assert suggest_rule(transaction).pattern == "RECU NOVATECH SARL"


def test_the_longest_run_wins_over_a_shorter_one() -> None:
    transaction = _transaction("PRLV EDF 12/05 ELECTRICITE VERTE ABONNEMENT")

    assert suggest_rule(transaction).pattern == "ELECTRICITE VERTE ABONNEMENT"


def test_ties_go_to_the_earliest_run() -> None:
    transaction = _transaction("PRLV AXA 4979 MMA")

    assert suggest_rule(transaction).pattern == "AXA"


def test_the_suggested_pattern_is_a_substring_of_the_description() -> None:
    description = "PAIEMENT CB 12/05 MONOPRIX PARIS 11 REF 998877"

    suggestion = suggest_rule(_transaction(description))

    assert suggestion.pattern in description


def test_a_label_of_pure_noise_falls_back_to_the_whole_label() -> None:
    transaction = _transaction("PRLV SEPA 14/05/2026 4979")

    assert suggest_rule(transaction).pattern == "PRLV SEPA 14/05/2026 4979"


def test_a_long_run_is_capped_without_cutting_a_word() -> None:
    words = ["MERCHANT"] * 40
    description = " ".join(words)

    pattern = suggest_rule(_transaction(description)).pattern

    assert len(pattern) <= MAX_PATTERN_LENGTH
    assert pattern.split() == words[: len(pattern.split())]
    assert not pattern.endswith("MERCHAN")


# --- GET /rules/suggestion ------------------------------------------------------------------


def test_the_endpoint_returns_the_suggestion(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    transaction_id = _insert_transaction(tmp_path, user_id, account_id, "PRLV SEPA ASSUR MAIF")

    response = client.get(
        "/api/v1/rules/suggestion", params={"transaction_id": transaction_id}, headers=headers
    )

    assert response.status_code == 200
    assert response.json() == {
        "match_field": "description_clean",
        "match_type": "contains",
        "pattern": "ASSUR MAIF",
    }


def test_the_endpoint_prefers_the_merchant_when_there_is_one(
    client: TestClient, tmp_path: Path
) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    transaction_id = _insert_transaction(tmp_path, user_id, account_id, "CB CARREFOUR CITY")
    client.patch(
        f"/api/v1/transactions/{transaction_id}",
        json={"merchant": "CARREFOUR CITY"},
        headers=headers,
    )

    response = client.get(
        "/api/v1/rules/suggestion", params={"transaction_id": transaction_id}, headers=headers
    )

    assert response.json() == {
        "match_field": "merchant",
        "match_type": "equals",
        "pattern": "CARREFOUR CITY",
    }


def test_the_suggestion_feeds_a_rule_that_matches_its_own_transaction(
    client: TestClient, tmp_path: Path
) -> None:
    """The whole point of the pre-fill: posting it back must catch the row it came from."""
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    transaction_id = _insert_transaction(
        tmp_path, user_id, account_id, "PAIEMENT CB 12/05 MONOPRIX PARIS 11 REF 998877"
    )

    suggestion = client.get(
        "/api/v1/rules/suggestion", params={"transaction_id": transaction_id}, headers=headers
    ).json()
    preview = client.post("/api/v1/rules/preview", json=suggestion, headers=headers).json()

    assert preview["match_count"] == 1
    assert preview["samples"][0]["id"] == transaction_id


def test_another_users_transaction_is_a_404(client: TestClient, tmp_path: Path) -> None:
    headers_a, _ = _register(client, "amelie@example.com")
    headers_b, user_id_b = _register(client, "bruno@example.com")
    account_id_b = _create_account(client, headers_b)
    transaction_id_b = _insert_transaction(
        tmp_path, user_id_b, account_id_b, "PRLV SEPA ASSUR MAIF"
    )

    response = client.get(
        "/api/v1/rules/suggestion", params={"transaction_id": transaction_id_b}, headers=headers_a
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "TRANSACTION_NOT_FOUND"


def test_the_endpoint_requires_auth(client: TestClient) -> None:
    response = client.get("/api/v1/rules/suggestion", params={"transaction_id": "t-1"})

    assert response.status_code == 401
