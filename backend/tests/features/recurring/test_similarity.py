"""Tests for which pairs of series are proposed as one subscription under two labels."""

from datetime import UTC, date, datetime

import pytest

from app.features.recurring.models import RecurringSeries
from app.features.recurring.similarity import dismissal_key, keys_alike, propose_merges


def _series(
    key: str,
    *,
    series_id: str | None = None,
    account_id: str = "account-1",
    cadence: str = "monthly",
    amount: int = -2499,
    last_seen: date = date(2026, 5, 3),
    status: str = "detected",
    is_manual: bool = False,
) -> RecurringSeries:
    return RecurringSeries(
        id=series_id or key,
        user_id="user-1",
        account_id=account_id,
        merchant_key=key,
        label=key.upper(),
        cadence=cadence,
        median_interval_days=30,
        expected_amount_minor=amount,
        currency="EUR",
        first_seen_date=date(2025, 1, 3),
        last_seen_date=last_seen,
        next_expected_date=last_seen,
        occurrence_count=3,
        status=status,
        is_manual=is_manual,
        created_at=datetime(2026, 1, 1, tzinfo=UTC),
    )


@pytest.mark.parametrize(
    ("key_a", "key_b"),
    [
        ("streamco", "streamco streamco tv"),
        ("streamco tv", "streamco tv europe"),
        ("gym club paris", "gym club paris 11"),
        ("gym club paris", "gym club lyon paris"),
    ],
)
def test_labels_that_extend_or_mostly_share_their_words_are_alike(key_a: str, key_b: str) -> None:
    assert keys_alike(key_a, key_b)
    assert keys_alike(key_b, key_a)


@pytest.mark.parametrize(
    ("key_a", "key_b"),
    [
        # Same leading word, but most of the rest differs: two merchants of one group.
        ("free mobile", "free box internet"),
        # Different leading words.
        ("streamco", "musico streamco"),
        # A leading word too short to name anyone.
        ("sa", "sa bricolage"),
        ("streamco", "streamco"),
    ],
)
def test_labels_that_only_brush_against_each_other_are_not(key_a: str, key_b: str) -> None:
    assert not keys_alike(key_a, key_b)


def test_the_series_still_charging_is_the_target() -> None:
    old = _series("streamco", last_seen=date(2026, 1, 3))
    new = _series("streamco streamco tv", last_seen=date(2026, 5, 3))

    [proposal] = propose_merges([new, old], dismissed=set())

    assert proposal.target is new
    assert proposal.source is old


@pytest.mark.parametrize(
    "other",
    [
        _series("streamco streamco tv", cadence="yearly"),
        # More than 25 % apart.
        _series("streamco streamco tv", amount=-3500),
        _series("streamco streamco tv", status="dismissed"),
        _series("streamco streamco tv", is_manual=True),
    ],
)
def test_a_pair_that_differs_in_kind_is_not_proposed(other: RecurringSeries) -> None:
    assert propose_merges([_series("streamco"), other], dismissed=set()) == []


def test_a_new_price_within_a_quarter_still_matches() -> None:
    old = _series("streamco", amount=-2499)
    new = _series("streamco streamco tv", amount=-2999)

    assert len(propose_merges([old, new], dismissed=set())) == 1


def test_a_cancelled_series_can_still_be_the_old_half() -> None:
    old = _series("streamco", status="cancelled", last_seen=date(2026, 1, 3))
    new = _series("streamco streamco tv")

    [proposal] = propose_merges([old, new], dismissed=set())

    assert proposal.source is old


def test_a_pair_the_user_kept_apart_is_not_proposed_again() -> None:
    dismissed = {dismissal_key(("account-1", "streamco streamco tv"), ("account-1", "streamco"))}

    assert propose_merges([_series("streamco"), _series("streamco streamco tv")], dismissed) == []


def test_every_pair_is_proposed_not_only_the_first() -> None:
    streamco_old = _series("streamco", last_seen=date(2026, 1, 3))
    streamco_new = _series("streamco streamco tv")
    gym_old = _series("gym club paris", amount=-3990, last_seen=date(2026, 2, 3))
    gym_new = _series("gym club paris 11", amount=-3990, account_id="account-2")

    proposals = propose_merges([streamco_old, gym_new, streamco_new, gym_old], dismissed=set())

    assert [(p.source, p.target) for p in proposals] == [
        (gym_old, gym_new),
        (streamco_old, streamco_new),
    ]


def test_a_subscription_moved_to_another_account_is_still_proposed() -> None:
    old = _series("streamco", account_id="account-1", last_seen=date(2026, 1, 3))
    new = _series("streamco streamco tv", account_id="account-2")

    [proposal] = propose_merges([old, new], dismissed=set())

    assert proposal.target is new
    assert proposal.source is old


def test_a_pair_kept_apart_across_accounts_is_not_proposed_again() -> None:
    old = _series("streamco", account_id="account-1")
    new = _series("streamco streamco tv", account_id="account-2")
    dismissed = {dismissal_key(("account-2", "streamco streamco tv"), ("account-1", "streamco"))}

    assert propose_merges([old, new], dismissed) == []


def test_the_dismissal_key_ignores_the_order_of_the_pair() -> None:
    a, b = ("acc-a", "y"), ("acc-b", "x")
    assert dismissal_key(a, b) == dismissal_key(b, a) == (a, b)
