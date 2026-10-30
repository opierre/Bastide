"""Tests for matching a card settlement to the cycle it paid, and offsetting it on the card."""

from dataclasses import dataclass
from datetime import date

from fastapi.testclient import TestClient

from app.features.imports.card_settlement import CARD_SETTLEMENT_CATEGORY_KEY, cycle_length
from tests.api import register as _register

#: January's cycle (−300.00 and −152.10) is settled by the 452.10 debit on 5 February; the
#: −40.00 on 2 February falls after the cycle close and belongs to the next one.
_CARD_ROWS = [
    ("C1", "20260105", "-300.00", "CB FNAC PARIS"),
    ("C2", "20260120", "-152.10", "CB SNCF"),
    ("C3", "20260202", "-40.00", "CB MONOPRIX"),
]
_SETTLEMENT = ("S1", "20260205", "-452.10", "FACTURE CARTE DU 310126")


@dataclass(frozen=True)
class _Row:
    booked_date: date
    amount_minor: int


def _statement(
    block: str, rows: list[tuple[str, str, str, str]], ledger: tuple[str, str] | None = None
) -> bytes:
    """A minimal OFX statement: ``block`` is the account block, `BANK` or `CC`."""
    transactions = "".join(
        f"<STMTTRN><TRNAMT>{amount}<DTPOSTED>{posted}<FITID>{fitid}<NAME>{name}</STMTTRN>\n"
        for fitid, posted, amount, name in rows
    )
    balance = f"<LEDGERBAL><BALAMT>{ledger[0]}<DTASOF>{ledger[1]}</LEDGERBAL>\n" if ledger else ""
    if block == "CC":
        account = "<CCACCTFROM><ACCTID>4970101012345678</CCACCTFROM>"
        open_tags, close_tags = (
            "<CREDITCARDMSGSRSV1><CCSTMTTRNRS><CCSTMTRS>",
            ("</CCSTMTRS></CCSTMTTRNRS></CREDITCARDMSGSRSV1>"),
        )
    else:
        account = "<BANKACCTFROM><BANKID>30004<ACCTID>0001234567<ACCTTYPE>CHECKING</BANKACCTFROM>"
        open_tags, close_tags = (
            "<BANKMSGSRSV1><STMTTRNRS><STMTRS>",
            ("</STMTRS></STMTTRNRS></BANKMSGSRSV1>"),
        )
    return (
        f"<OFX>\n{open_tags}\n<CURDEF>EUR\n{account}\n"
        f"<BANKTRANLIST>\n{transactions}</BANKTRANLIST>\n{balance}{close_tags}\n</OFX>\n"
    ).encode()


def _create_account(client: TestClient, headers: dict[str, str], type_: str) -> str:
    response = client.post(
        "/api/v1/accounts",
        json={
            "name": type_,
            "type": type_,
            "institution": "BNP Paribas",
            "opening_balance_minor": 0,
            "settlement_account_id": _settlement_account(client, headers)
            if type_ == "deferred_card"
            else None,
        },
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["id"]


def _settlement_account(client: TestClient, headers: dict[str, str]) -> str:
    """An account for a card to be settled from; cards must name one."""
    response = client.post(
        "/api/v1/accounts",
        json={
            "name": "Payer",
            "type": "savings",
            "institution": "Autre",
            "opening_balance_minor": 0,
        },
        headers=headers,
    )
    return response.json()["id"]


def _import(
    client: TestClient, headers: dict[str, str], account_id: str, content: bytes, name: str
) -> dict:
    response = client.post(
        "/api/v1/imports",
        headers=headers,
        data={"account_id": account_id},
        files={"file": (name, content, "application/octet-stream")},
    )
    assert response.status_code == 201, response.json()
    return response.json()


def _rows(client: TestClient, headers: dict[str, str], account_id: str) -> list[dict]:
    return client.get(
        "/api/v1/transactions", params={"account_id": account_id}, headers=headers
    ).json()["items"]


def _balance(client: TestClient, headers: dict[str, str], account_id: str) -> int:
    return client.get(f"/api/v1/accounts/{account_id}", headers=headers).json()["balance_minor"]


def _offsets(rows: list[dict]) -> list[dict]:
    return [row for row in rows if row["amount_minor"] > 0]


def _category_id(client: TestClient, headers: dict[str, str], key: str) -> str:
    categories = client.get("/api/v1/categories", headers=headers).json()
    return next(category["id"] for category in categories if category["name"] == key)


def _recategorize(
    client: TestClient, headers: dict[str, str], transaction_id: str, category_id: str
) -> dict:
    response = client.patch(
        f"/api/v1/transactions/{transaction_id}",
        json={"category_id": category_id},
        headers=headers,
    )
    assert response.status_code == 200, response.json()
    return response.json()


def _settled(client: TestClient, headers: dict[str, str]) -> tuple[str, str, dict]:
    """A card cycle matched to its settlement: the checking id, the card id, the settlement."""
    checking_id = _create_account(client, headers, "checking")
    card_id = _create_account(client, headers, "deferred_card")
    _import(client, headers, card_id, _statement("CC", _CARD_ROWS), "carte.ofx")
    _import(client, headers, checking_id, _statement("BANK", [_SETTLEMENT]), "releve.ofx")
    return checking_id, card_id, _rows(client, headers, checking_id)[0]


# --- cycle matching ---------------------------------------------------------------------


def test_the_cycle_ends_at_the_day_its_total_reaches_the_settlement() -> None:
    rows = [
        _Row(date(2026, 1, 5), -30_000),
        _Row(date(2026, 1, 20), -15_210),
        _Row(date(2026, 2, 2), -4_000),
    ]

    assert cycle_length(rows, -45_210) == 2


def test_a_cycle_never_splits_a_day() -> None:
    # The first row alone reaches the total, but the cycle can't close mid-day.
    rows = [_Row(date(2026, 1, 5), -45_210), _Row(date(2026, 1, 5), -1_000)]

    assert cycle_length(rows, -45_210) is None


def test_no_cycle_fits_a_settlement_its_rows_never_total() -> None:
    rows = [_Row(date(2026, 1, 5), -30_000), _Row(date(2026, 1, 20), -15_000)]

    assert cycle_length(rows, -45_210) is None
    assert cycle_length([], -45_210) is None


# --- linking through the import endpoint ------------------------------------------------


def test_card_then_checking_offsets_the_cycle_on_the_card(client: TestClient) -> None:
    headers = _register(client)
    checking_id = _create_account(client, headers, "checking")
    card_id = _create_account(client, headers, "deferred_card")

    _import(client, headers, card_id, _statement("CC", _CARD_ROWS), "carte.ofx")
    _import(client, headers, checking_id, _statement("BANK", [_SETTLEMENT]), "releve.ofx")

    offsets = _offsets(_rows(client, headers, card_id))
    assert len(offsets) == 1
    assert offsets[0]["amount_minor"] == 45_210
    assert offsets[0]["booked_date"] == "2026-02-05"
    assert offsets[0]["description_raw"] == "FACTURE CARTE DU 310126"
    assert offsets[0]["category"]["name"] == CARD_SETTLEMENT_CATEGORY_KEY
    # January is paid off; only February's purchase is still owed.
    assert _balance(client, headers, card_id) == -4_000
    assert _balance(client, headers, checking_id) == -45_210


def test_checking_then_card_offsets_the_cycle_on_the_card(client: TestClient) -> None:
    headers = _register(client)
    checking_id = _create_account(client, headers, "checking")
    card_id = _create_account(client, headers, "deferred_card")

    _import(client, headers, checking_id, _statement("BANK", [_SETTLEMENT]), "releve.ofx")
    _import(client, headers, card_id, _statement("CC", _CARD_ROWS), "carte.ofx")

    assert [row["amount_minor"] for row in _offsets(_rows(client, headers, card_id))] == [45_210]
    assert _balance(client, headers, card_id) == -4_000


def test_a_settlement_imported_before_its_card_existed_is_linked_later(
    client: TestClient,
) -> None:
    headers = _register(client)
    checking_id = _create_account(client, headers, "checking")
    _import(client, headers, checking_id, _statement("BANK", [_SETTLEMENT]), "releve.ofx")
    assert _rows(client, headers, checking_id)[0]["category"] is None

    card_id = _create_account(client, headers, "deferred_card")
    _import(client, headers, card_id, _statement("CC", _CARD_ROWS), "carte.ofx")

    settlement = _rows(client, headers, checking_id)[0]
    assert settlement["category"]["name"] == CARD_SETTLEMENT_CATEGORY_KEY
    assert settlement["categorization_source"] == "detected"
    assert settlement["needs_review"] is True
    assert _balance(client, headers, card_id) == -4_000


def test_a_matched_settlement_is_offset_once(client: TestClient) -> None:
    headers = _register(client)
    checking_id = _create_account(client, headers, "checking")
    card_id = _create_account(client, headers, "deferred_card")
    _import(client, headers, card_id, _statement("CC", _CARD_ROWS), "carte.ofx")
    _import(client, headers, checking_id, _statement("BANK", [_SETTLEMENT]), "releve.ofx")

    # A later, overlapping statement re-sends the settlement and adds a new row.
    later = [_SETTLEMENT, ("S2", "20260210", "-20.00", "CB PHARMACIE")]
    _import(client, headers, checking_id, _statement("BANK", later), "releve-2.ofx")

    assert len(_offsets(_rows(client, headers, card_id))) == 1
    assert _balance(client, headers, card_id) == -4_000


def test_the_card_statement_own_reset_line_is_the_offset(client: TestClient) -> None:
    headers = _register(client)
    checking_id = _create_account(client, headers, "checking")
    card_id = _create_account(client, headers, "deferred_card")
    reset = ("R1", "20260204", "452.10", "RELEVE DIFFERE AU 310126")

    _import(client, headers, card_id, _statement("CC", [*_CARD_ROWS, reset]), "carte.ofx")
    _import(client, headers, checking_id, _statement("BANK", [_SETTLEMENT]), "releve.ofx")

    offsets = _offsets(_rows(client, headers, card_id))
    assert [row["description_raw"] for row in offsets] == ["RELEVE DIFFERE AU 310126"]
    assert offsets[0]["category"]["name"] == CARD_SETTLEMENT_CATEGORY_KEY
    assert _balance(client, headers, card_id) == -4_000


def test_a_settlement_no_cycle_totals_is_left_unlinked(client: TestClient) -> None:
    headers = _register(client)
    checking_id = _create_account(client, headers, "checking")
    card_id = _create_account(client, headers, "deferred_card")
    off_by_a_cent = ("S1", "20260205", "-452.11", "FACTURE CARTE DU 310126")

    _import(client, headers, card_id, _statement("CC", _CARD_ROWS), "carte.ofx")
    _import(client, headers, checking_id, _statement("BANK", [off_by_a_cent]), "releve.ofx")

    assert _offsets(_rows(client, headers, card_id)) == []
    assert _balance(client, headers, card_id) == -49_210


def test_two_cards_fitting_one_settlement_are_not_guessed_between(client: TestClient) -> None:
    headers = _register(client)
    checking_id = _create_account(client, headers, "checking")
    first_card = _create_account(client, headers, "deferred_card")
    second_card = _create_account(client, headers, "deferred_card")
    cycle = [("C1", "20260120", "-452.10", "CB FNAC PARIS")]

    _import(client, headers, first_card, _statement("CC", cycle), "carte-1.ofx")
    _import(
        client,
        headers,
        second_card,
        _statement("CC", [("D1", "20260121", "-452.10", "CB DARTY")]),
        "carte-2.ofx",
    )
    _import(client, headers, checking_id, _statement("BANK", [_SETTLEMENT]), "releve.ofx")

    assert _offsets(_rows(client, headers, first_card)) == []
    assert _offsets(_rows(client, headers, second_card)) == []


def test_a_card_first_import_reconciles_against_the_offset(client: TestClient) -> None:
    # The card statement declares −40.00 on 3 February: January was settled, only February's
    # purchase is owed. Linking runs before the opening balance is derived, so the opening stays
    # at zero instead of absorbing the settlement the statement never printed.
    headers = _register(client)
    checking_id = _create_account(client, headers, "checking")
    card_id = _create_account(client, headers, "deferred_card")
    settled_early = ("S1", "20260203", "-452.10", "FACTURE CARTE DU 310126")

    _import(client, headers, checking_id, _statement("BANK", [settled_early]), "releve.ofx")
    _import(
        client,
        headers,
        card_id,
        _statement("CC", _CARD_ROWS, ledger=("-40.00", "20260203")),
        "carte.ofx",
    )

    card = client.get(f"/api/v1/accounts/{card_id}", headers=headers).json()
    assert card["opening_balance_minor"] == 0
    assert card["balance_minor"] == -4_000


# --- confirming and correcting a detected settlement ------------------------------------


def test_confirming_a_settlement_keeps_its_link(client: TestClient) -> None:
    headers = _register(client)
    checking_id, card_id, settlement = _settled(client, headers)

    confirmed = _recategorize(client, headers, settlement["id"], settlement["category"]["id"])

    assert confirmed["categorization_source"] == "user"
    assert confirmed["needs_review"] is False
    assert len(_offsets(_rows(client, headers, card_id))) == 1
    assert _balance(client, headers, card_id) == -4_000


def test_correcting_a_settlement_removes_the_posted_credit(client: TestClient) -> None:
    headers = _register(client)
    checking_id, card_id, settlement = _settled(client, headers)
    other = _category_id(client, headers, "category.other.uncategorized")

    _recategorize(client, headers, settlement["id"], other)

    # The cycle is owed again, as if the settlement had never been matched.
    assert _offsets(_rows(client, headers, card_id)) == []
    assert _balance(client, headers, card_id) == -49_210

    # And it stays the user's call: a later import does not match it again.
    later = [("S2", "20260210", "-20.00", "CB PHARMACIE")]
    _import(client, headers, checking_id, _statement("BANK", later), "releve-2.ofx")
    assert _offsets(_rows(client, headers, card_id)) == []


def test_correcting_a_settlement_sends_the_bank_reset_line_back_to_review(
    client: TestClient,
) -> None:
    headers = _register(client)
    checking_id = _create_account(client, headers, "checking")
    card_id = _create_account(client, headers, "deferred_card")
    reset = ("R1", "20260204", "452.10", "RELEVE DIFFERE AU 310126")
    _import(client, headers, card_id, _statement("CC", [*_CARD_ROWS, reset]), "carte.ofx")
    _import(client, headers, checking_id, _statement("BANK", [_SETTLEMENT]), "releve.ofx")
    settlement = _rows(client, headers, checking_id)[0]

    _recategorize(
        client,
        headers,
        settlement["id"],
        _category_id(client, headers, "category.other.uncategorized"),
    )

    # The bank's line is a real row, so it stays; only our reading of it is withdrawn.
    line = _offsets(_rows(client, headers, card_id))[0]
    assert line["description_raw"] == "RELEVE DIFFERE AU 310126"
    assert line["category"] is None
    assert line["needs_review"] is True
    assert _balance(client, headers, card_id) == -4_000


# --- a reset line arriving after the credit was posted -----------------------------------


def test_a_late_reset_line_replaces_the_posted_credit(client: TestClient) -> None:
    headers = _register(client)
    _, card_id, _ = _settled(client, headers)
    assert [row["description_raw"] for row in _offsets(_rows(client, headers, card_id))] == [
        "FACTURE CARTE DU 310126"
    ]

    # February's card statement prints the settlement as its own reset line.
    february = [
        ("R1", "20260204", "452.10", "RELEVE DIFFERE AU 310126"),
        ("C4", "20260215", "-25.00", "CB BOULANGERIE"),
    ]
    _import(client, headers, card_id, _statement("CC", february), "carte-2.ofx")

    offsets = _offsets(_rows(client, headers, card_id))
    assert [row["description_raw"] for row in offsets] == ["RELEVE DIFFERE AU 310126"]
    assert offsets[0]["category"]["name"] == CARD_SETTLEMENT_CATEGORY_KEY
    # Credited once: −300.00 −152.10 −40.00 +452.10 −25.00.
    assert _balance(client, headers, card_id) == -6_500


def test_a_late_reset_line_counts_toward_the_declared_balance(client: TestClient) -> None:
    # The second statement declares what the card owes after the swap. Had the posted credit
    # stayed beside the reset line, the ledger would sit 452.10 above it and flag a mismatch.
    headers = _register(client)
    _, card_id, _ = _settled(client, headers)
    february = [("R1", "20260204", "452.10", "RELEVE DIFFERE AU 310126")]

    batch = _import(
        client,
        headers,
        card_id,
        _statement("CC", february, ledger=("-40.00", "20260204")),
        "carte-2.ofx",
    )

    assert batch["balance_mismatch_minor"] is None
    assert _balance(client, headers, card_id) == -4_000


def test_a_rule_moving_a_settlement_elsewhere_removes_the_posted_credit(
    client: TestClient,
) -> None:
    # « Exécuter les règles » is the user's instruction too: a rule filing the settlement under
    # another category undoes the link exactly as « Corriger » would.
    headers = _register(client)
    _, card_id, _ = _settled(client, headers)
    created = client.post(
        "/api/v1/rules",
        json={
            "priority": 1,
            "match_field": "description_clean",
            "match_type": "contains",
            "pattern": "FACTURE CARTE",
            "category_id": _category_id(client, headers, "category.other.uncategorized"),
        },
        headers=headers,
    )
    assert created.status_code == 201, created.json()

    applied = client.post("/api/v1/rules/apply", json={}, headers=headers)

    assert applied.status_code == 200, applied.json()
    assert applied.json()["recategorized_count"] == 1
    assert _offsets(_rows(client, headers, card_id)) == []
    assert _balance(client, headers, card_id) == -49_210


def test_a_rule_never_recategorises_the_card_credit_on_its_own(client: TestClient) -> None:
    # The credit carries the settlement's wording, so a rule written for that wording matches
    # it too. With the settlement confirmed — and so out of the rules' reach — the credit must
    # keep following its link rather than become an income line on the card.
    headers = _register(client)
    _, card_id, settlement = _settled(client, headers)
    _recategorize(client, headers, settlement["id"], settlement["category"]["id"])
    client.post(
        "/api/v1/rules",
        json={
            "priority": 1,
            "match_field": "description_clean",
            "match_type": "contains",
            "pattern": "FACTURE CARTE",
            "category_id": _category_id(client, headers, "category.other.uncategorized"),
        },
        headers=headers,
    )

    applied = client.post("/api/v1/rules/apply", json={}, headers=headers)

    assert applied.json()["recategorized_count"] == 0
    offsets = _offsets(_rows(client, headers, card_id))
    assert [row["category"]["name"] for row in offsets] == [CARD_SETTLEMENT_CATEGORY_KEY]
    assert _balance(client, headers, card_id) == -4_000


# --- what is left to settle -------------------------------------------------------------


def _status(client: TestClient, headers: dict[str, str]) -> dict:
    response = client.get("/api/v1/imports/card-settlements", headers=headers)
    assert response.status_code == 200, response.json()
    return response.json()


def test_a_user_tracking_no_card_has_nothing_to_settle(client: TestClient) -> None:
    headers = _register(client)
    checking_id = _create_account(client, headers, "checking")
    # A settlement-looking debit with no card to pay: it is the only record of that
    # spending, so there is nothing to confirm and nothing counted twice.
    _import(client, headers, checking_id, _statement("BANK", [_SETTLEMENT]), "releve.ofx")

    assert _status(client, headers) == {"proposed_count": 0, "unmatched": []}


def test_a_detected_settlement_waits_for_confirmation(client: TestClient) -> None:
    headers = _register(client)
    _, _, settlement = _settled(client, headers)

    assert _status(client, headers)["proposed_count"] == 1

    _recategorize(client, headers, settlement["id"], settlement["category"]["id"])

    assert _status(client, headers)["proposed_count"] == 0


def test_a_settled_cycle_and_a_recent_purchase_are_not_flagged(client: TestClient) -> None:
    headers = _register(client)
    _settled(client, headers)

    # January is settled, and February's −40.00 is not due yet on 5 February.
    assert _status(client, headers)["unmatched"] == []


def test_purchases_an_unrecognised_debit_paid_are_flagged(client: TestClient) -> None:
    headers = _register(client)
    checking_id = _create_account(client, headers, "checking")
    card_id = _create_account(client, headers, "deferred_card")
    _import(client, headers, card_id, _statement("CC", _CARD_ROWS), "carte.ofx")
    # The bank words the debit in a way no marker reads, and the current account runs on
    # well past it: the card purchases now count twice.
    unrecognised = [
        ("S1", "20260205", "-452.10", "PRLV BNP PARIBAS 0126"),
        ("S2", "20260325", "-12.00", "CB BOULANGERIE"),
    ]
    _import(client, headers, checking_id, _statement("BANK", unrecognised), "releve.ofx")

    assert _status(client, headers)["unmatched"] == [
        {
            "account_id": card_id,
            "amount_minor": -49_210,
            "count": 3,
            "since": "2026-01-05",
        }
    ]
