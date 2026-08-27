"""Tests for the merchant key. Real French bank label shapes must collapse to one key.

Every grouping decision downstream rests on this function, and its two failure modes cost the
same: a key that varies between occurrences hides a subscription, a key that collapses two
merchants invents one.
"""

import pytest

from app.features.recurring.normalize import merchant_key, normalize_label
from app.features.transactions.models import Transaction


def _transaction(description_clean: str, merchant: str | None = None) -> Transaction:
    return Transaction(
        description_raw=description_clean,
        description_clean=description_clean,
        merchant=merchant,
        amount_minor=-999,
        currency="EUR",
    )


# --- what varies between occurrences of one merchant ----------------------------------------


@pytest.mark.parametrize(
    ("label", "expected"),
    [
        # Card payments: a `CB` wrapper, the operation date, and the card sequence.
        ("CB CARREFOUR MARKET 14/05 CB4979", "carrefour market"),
        ("CB CARREFOUR MARKET 12/06 CB4979", "carrefour market"),
        ("PAIEMENT CB CARREFOUR MARKET 09/07 CB4979", "carrefour market"),
        ("ACHAT CB CARREFOUR MARKET 08.08.26 CB4979", "carrefour market"),
        # Direct debits: the SEPA wrapper, the mandate, the reference number.
        ("PRLV SEPA NETFLIX.COM REF 250114887", "netflix.com"),
        ("PRLV SEPA NETFLIX.COM REF 260214913", "netflix.com"),
        # Transfers: the échéance and the RUM.
        ("VIR SEPA EDF ECHEANCE 04/2026 RUM 4XZ12", "edf"),
        ("VIREMENT SEPA EDF ECHEANCE 05/2026 RUM 4XZ12", "edf"),
        # Case and spacing are the bank's, not the merchant's.
        ("cb   Carrefour Market 14/05 CB4979", "carrefour market"),
    ],
)
def test_variable_parts_are_stripped(label: str, expected: str) -> None:
    assert normalize_label(label) == expected


def test_occurrences_of_one_subscription_share_a_key() -> None:
    labels = [
        "PRLV SEPA SPOTIFY REF 250114887",
        "PRLV SEPA SPOTIFY REF 260214913",
        "PRLV SEPA SPOTIFY REF 260315004",
    ]

    keys = {merchant_key(_transaction(label)) for label in labels}

    assert keys == {"spotify"}


# --- what must not collapse ------------------------------------------------------------------


@pytest.mark.parametrize(
    ("left", "right"),
    [
        ("CB CARREFOUR MARKET 14/05 CB4979", "CB CARREFOUR CITY 14/05 CB4979"),
        ("PRLV SEPA NETFLIX.COM REF 250114887", "PRLV SEPA SPOTIFY REF 250114887"),
        ("CB FNAC 14/05 CB4979", "CB DARTY 14/05 CB4979"),
        ("VIR SEPA EDF ECHEANCE 04/2026", "VIR SEPA ENGIE ECHEANCE 04/2026"),
    ],
)
def test_different_merchants_keep_different_keys(left: str, right: str) -> None:
    assert normalize_label(left) != normalize_label(right)


def test_label_of_nothing_but_noise_falls_back_to_the_whole_label() -> None:
    """An empty key would file every noise-only row under one group and invent a series."""
    assert normalize_label("PRLV SEPA 14/05") == "prlv sepa 14/05"


# --- which field the key is taken from -------------------------------------------------------


def test_merchant_is_preferred_over_the_description() -> None:
    transaction = _transaction("CB SPOTIFY 12/05 CB4979", merchant="SPOTIFY")

    assert merchant_key(transaction) == "spotify"


def test_an_extracted_merchant_is_stripped_like_a_description() -> None:
    """`extract_merchant` only removes a prefix, so what it leaves still carries the noise."""
    from_merchant = _transaction("CB SPOTIFY 12/05 CB4979", merchant="SPOTIFY 12/05 CB4979")
    from_description = _transaction("CB SPOTIFY 09/06 CB4979")

    assert merchant_key(from_merchant) == merchant_key(from_description) == "spotify"


def test_blank_merchant_falls_back_to_the_description() -> None:
    assert merchant_key(_transaction("CB SPOTIFY 12/05 CB4979", merchant="   ")) == "spotify"
