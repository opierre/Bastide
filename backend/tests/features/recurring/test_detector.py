"""Tests for the detection algorithm — one table per rule.

Both directions matter for every rule: what qualifies, and what a hair outside the tolerance
does not. A detector that is too generous fills the subscriptions screen with noise the user
has to dismiss one by one, which is worse than one it misses.
"""

from datetime import date, timedelta

import pytest

from app.features.recurring.detector import SeriesCandidate, detect
from app.features.transactions.models import Transaction

START = date(2026, 1, 15)


def _transaction(
    day_offset: int,
    amount_minor: int,
    *,
    description: str = "PRLV SEPA NETFLIX.COM REF 250114887",
    account_id: str = "account-1",
    merchant: str | None = None,
    index: int = 0,
) -> Transaction:
    return Transaction(
        id=f"tx-{account_id}-{day_offset}-{index}",
        account_id=account_id,
        booked_date=START + timedelta(days=day_offset),
        amount_minor=amount_minor,
        currency="EUR",
        description_raw=description,
        description_clean=description,
        merchant=merchant,
    )


def _series(offsets: list[int], amounts: list[int], **kwargs: str) -> list[Transaction]:
    """One merchant's occurrences: ``offsets`` days after START, at ``amounts``."""
    return [
        _transaction(offset, amount, index=index, **kwargs)
        for index, (offset, amount) in enumerate(zip(offsets, amounts, strict=True))
    ]


def _only(transactions: list[Transaction]) -> SeriesCandidate:
    candidates = detect(transactions)
    assert len(candidates) == 1
    return candidates[0]


# --- the qualifying case ---------------------------------------------------------------------


def test_three_regular_monthly_charges_make_one_monthly_series() -> None:
    candidate = _only(_series([0, 30, 60], [-999, -999, -999]))

    assert candidate.cadence == "monthly"
    assert candidate.median_interval_days == 30
    assert candidate.expected_amount_minor == -999
    assert candidate.occurrence_count == 3
    assert candidate.first_seen_date == START
    assert candidate.last_seen_date == START + timedelta(days=60)
    assert candidate.next_expected_date == START + timedelta(days=90)
    assert candidate.price_change_minor is None
    assert candidate.price_changed_at is None
    assert candidate.currency == "EUR"
    assert candidate.merchant_key == "netflix.com"
    assert candidate.transaction_ids == tuple(
        t.id for t in _series([0, 30, 60], [-999, -999, -999])
    )


# --- occurrence count ------------------------------------------------------------------------


def test_two_occurrences_are_a_coincidence_not_a_series() -> None:
    assert detect(_series([0, 30], [-999, -999])) == []


# --- cadence classification ------------------------------------------------------------------


@pytest.mark.parametrize(
    ("offsets", "cadence", "interval"),
    [
        ([0, 7, 14], "weekly", 7),
        ([0, 5, 10], "weekly", 5),
        ([0, 9, 18], "weekly", 9),
        ([0, 30, 60], "monthly", 30),
        ([0, 26, 52], "monthly", 26),
        ([0, 35, 70], "monthly", 35),
        ([0, 91, 182], "quarterly", 91),
        ([0, 85, 170], "quarterly", 85),
        ([0, 95, 190], "quarterly", 95),
        ([0, 365, 730], "yearly", 365),
        ([0, 350, 700], "yearly", 350),
        ([0, 380, 760], "yearly", 380),
    ],
)
def test_median_gap_classifies_the_cadence(offsets: list[int], cadence: str, interval: int) -> None:
    candidate = _only(_series(offsets, [-999] * len(offsets)))

    assert candidate.cadence == cadence
    assert candidate.median_interval_days == interval


@pytest.mark.parametrize("offsets", [[0, 3, 6], [0, 15, 30], [0, 60, 120], [0, 200, 400]])
def test_a_median_gap_outside_every_band_yields_no_series(offsets: list[int]) -> None:
    """Fortnightly, bimonthly, twice-yearly: regular, but not a recognised cadence."""
    assert detect(_series(offsets, [-999] * len(offsets))) == []


# --- gap regularity --------------------------------------------------------------------------


def test_irregular_gaps_yield_no_series() -> None:
    assert detect(_series([0, 30, 75], [-999, -999, -999])) == []


@pytest.mark.parametrize(
    ("offsets", "qualifies"),
    [
        # Floor: ±3 days around a weekly median, where ±25 % would only be ±1.75.
        ([0, 7, 17], True),
        ([0, 7, 18], False),
        # Percentage: ±25 % of a 32-day median is exactly ±8 days.
        ([0, 32, 72], True),
        ([0, 32, 73], False),
    ],
)
def test_gap_tolerance_boundaries(offsets: list[int], qualifies: bool) -> None:
    assert bool(detect(_series(offsets, [-999] * len(offsets)))) is qualifies


# --- amount regularity -----------------------------------------------------------------------


def test_wildly_varying_amounts_yield_no_series() -> None:
    assert detect(_series([0, 30, 60], [-1000, -5000, -20000])) == []


def test_a_subscription_varying_by_a_couple_of_cents_still_qualifies() -> None:
    """The minor-unit floor: ±10 % of €9.99 is 100 minor units, ±200 is the one that applies."""
    candidate = _only(_series([0, 30, 60], [-999, -1001, -1000]))

    assert candidate.expected_amount_minor == -1000
    assert candidate.price_change_minor is None


@pytest.mark.parametrize(
    ("amounts", "qualifies"),
    [
        # Floor: ±200 minor units around €10.00, where ±10 % would only be ±100.
        ([-1000, -1000, -1200], True),
        ([-1201, -1000, -1000], False),
        # Percentage: ±10 % of €100.00 is exactly ±1000 minor units.
        ([-10_000, -10_000, -11_000], True),
        ([-11_001, -10_000, -10_000], False),
    ],
)
def test_amount_tolerance_boundaries(amounts: list[int], qualifies: bool) -> None:
    """The outlier sits first, so failing it is the amount test and not a price change."""
    assert bool(detect(_series([0, 30, 60], amounts))) is qualifies


# --- price change ----------------------------------------------------------------------------


def test_a_price_increase_keeps_the_series_and_rebaselines_it() -> None:
    candidate = _only(_series([0, 30, 60], [-999, -999, -1299]))

    assert candidate.cadence == "monthly"
    assert candidate.expected_amount_minor == -1299
    # Signed step in `expected_amount_minor`: a rise on an outflow is negative.
    assert candidate.price_change_minor == -300
    assert candidate.price_changed_at == START + timedelta(days=60)


def test_a_price_decrease_is_recorded_the_same_way() -> None:
    candidate = _only(_series([0, 30, 60], [-1299, -1299, -999]))

    assert candidate.expected_amount_minor == -999
    assert candidate.price_change_minor == 300


def test_a_price_change_does_not_make_the_series_fail_its_own_amount_test() -> None:
    """Regularity is judged on the pre-change occurrences, or the step would sink the series."""
    candidate = _only(_series([0, 30, 60, 90], [-999, -999, -999, -1899]))

    assert candidate.occurrence_count == 4
    assert candidate.expected_amount_minor == -1899
    assert candidate.price_change_minor == -900


def test_a_price_change_on_irregular_gaps_is_still_no_series() -> None:
    """Only the amounts get the benefit of the doubt; the cadence must hold on its own."""
    assert detect(_series([0, 30, 75], [-999, -999, -1299])) == []


# --- outflows only ---------------------------------------------------------------------------


def test_inflows_are_never_detected_as_subscriptions() -> None:
    """A salary is a rhythm, but it is not something the user is paying for."""
    salary = _series([0, 30, 60], [250_000, 250_000, 250_000], description="VIR SEPA SALAIRE")

    assert detect(salary) == []


def test_inflows_do_not_count_towards_a_merchant_s_occurrences() -> None:
    """Two charges and a refund from the same merchant are still only two charges."""
    transactions = _series([0, 30, 60], [-999, 999, -999])

    assert detect(transactions) == []


# --- grouping --------------------------------------------------------------------------------


def test_the_same_merchant_in_two_accounts_makes_two_series() -> None:
    candidates = detect(
        _series([0, 30, 60], [-999] * 3, account_id="account-1")
        + _series([0, 30, 60], [-1999] * 3, account_id="account-2")
    )

    assert [candidate.account_id for candidate in candidates] == ["account-1", "account-2"]
    assert [candidate.expected_amount_minor for candidate in candidates] == [-999, -1999]


def test_two_merchants_are_two_series() -> None:
    candidates = detect(
        _series([0, 30, 60], [-999] * 3, description="PRLV SEPA SPOTIFY REF 250114887")
        + _series([0, 31, 59], [-1799] * 3, description="PRLV SEPA NETFLIX.COM REF 250114887")
    )

    assert sorted(candidate.merchant_key for candidate in candidates) == [
        "netflix.com",
        "spotify",
    ]


def test_occurrences_are_grouped_across_the_labels_the_bank_varies() -> None:
    transactions = [
        _transaction(0, -999, description="CB SPOTIFY 15/01 CB4979"),
        _transaction(30, -999, description="CB SPOTIFY 14/02 CB4979"),
        _transaction(60, -999, description="PAIEMENT CB SPOTIFY 16/03 CB4979"),
    ]

    candidate = _only(transactions)

    assert candidate.merchant_key == "spotify"
    assert candidate.occurrence_count == 3


def test_the_label_defaults_to_the_prettiest_observed_merchant() -> None:
    """The occurrence whose merchant the bank left alone, not one carrying a date and a card."""
    transactions = [
        _transaction(0, -999, merchant="SPOTIFY 15/01 CB4979"),
        _transaction(30, -999, merchant="SPOTIFY 14/02 CB4979"),
        _transaction(60, -999, merchant="SPOTIFY"),
    ]

    candidate = _only(transactions)

    assert candidate.merchant_key == "spotify"
    assert candidate.label == "SPOTIFY"
