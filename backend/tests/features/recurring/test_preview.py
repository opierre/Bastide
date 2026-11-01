"""Tests for grading a would-be series: one case per confidence level and per reason."""

from datetime import date, timedelta

import pytest

from app.features.recurring.preview import grade
from app.features.transactions.models import Transaction

START = date(2026, 1, 15)


def _group(offsets: list[int], amounts: list[int]) -> list[Transaction]:
    return [
        Transaction(
            id=f"tx-{index}",
            account_id="account-1",
            booked_date=START + timedelta(days=offset),
            amount_minor=amount,
            currency="EUR",
            description_raw="PRLV SEPA STREAMCO",
            description_clean="PRLV SEPA STREAMCO",
            merchant="STREAMCO",
        )
        for index, (offset, amount) in enumerate(zip(offsets, amounts, strict=True))
    ]


def test_a_group_the_detector_accepts_is_high() -> None:
    result = grade(_group([0, 30, 61], [-999, -999, -999]))

    assert result.confidence == "high"
    assert result.reasons == ("occurrences", "cadence_monthly", "amount_stable")
    assert result.cadence == "monthly"
    assert result.median_interval_days == 30
    assert result.expected_amount_minor == -999
    assert result.label == "STREAMCO"


def test_a_price_change_on_the_newest_charge_stays_high() -> None:
    result = grade(_group([0, 30, 60], [-999, -999, -1299]))

    assert result.confidence == "high"
    assert "amount_changed" in result.reasons
    assert result.expected_amount_minor == -1299


def test_the_transactions_come_back_oldest_first() -> None:
    group = _group([0, 30, 60], [-999, -999, -999])

    result = grade(list(reversed(group)))

    assert [t.id for t in result.transactions] == ["tx-0", "tx-1", "tx-2"]


def test_two_charges_on_a_cadence_are_medium() -> None:
    result = grade(_group([0, 7], [-450, -450]))

    assert result.confidence == "medium"
    assert result.cadence == "weekly"
    assert "too_few_occurrences" in result.reasons


def test_one_gap_outside_the_tolerance_is_medium() -> None:
    result = grade(_group([0, 30, 60, 105], [-999, -999, -999, -999]))

    assert result.confidence == "medium"
    assert result.cadence == "monthly"
    assert "gap_outside_tolerance" in result.reasons


def test_one_amount_outside_the_tolerance_is_medium() -> None:
    result = grade(_group([0, 30, 60, 90], [-999, -2500, -999, -999]))

    assert result.confidence == "medium"
    assert "amount_outside_tolerance" in result.reasons
    assert result.expected_amount_minor == -999


def test_two_deviations_are_low() -> None:
    result = grade(_group([0, 30, 60, 105], [-999, -2500, -999, -999]))

    assert result.confidence == "low"
    assert result.cadence == "irregular"
    assert "no_rhythm" in result.reasons


@pytest.mark.parametrize(
    ("offsets", "amounts", "reason"),
    [
        ([0], [-1200], "too_few_occurrences"),
        ([0, 14, 60], [-1200, -1200, -1200], "no_rhythm"),
    ],
)
def test_no_recognised_rhythm_is_low_and_irregular(
    offsets: list[int], amounts: list[int], reason: str
) -> None:
    result = grade(_group(offsets, amounts))

    assert result.confidence == "low"
    assert result.cadence == "irregular"
    assert result.median_interval_days == 0
    assert result.expected_amount_minor == -1200
    assert reason in result.reasons


def test_an_empty_group_cannot_be_graded() -> None:
    with pytest.raises(ValueError, match="empty"):
        grade([])
