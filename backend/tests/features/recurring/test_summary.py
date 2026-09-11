"""Tests for the subscriptions summary: the monthly burden, the counts, and the read-time signals.

The burden is asserted against the set the panel actually draws
(`docs/design/10-subscriptions.md`, frame ①), because the three summary cards print one figure
each and the whole point of computing them server-side is that they cannot disagree.

`today` is passed to the service directly rather than through the endpoint: the route reads the
real clock, which would make every date assertion below expire as soon as the calendar moved on.
"""

from datetime import date, timedelta
from pathlib import Path

from fastapi.testclient import TestClient

from app.features.accounts.repository import AccountRepository
from app.features.accounts.service import AccountService
from app.features.categories.repository import CategoryRepository
from app.features.recurring.repository import RecurringRepository
from app.features.recurring.schemas import RecurringSummary
from app.features.recurring.service import RecurringService, monthly_equivalent_minor
from app.features.transactions.repository import TransactionRepository
from tests.features.recurring.factories import (
    Owner,
    create_account,
    insert_series,
    insert_transaction,
    open_session,
    read_series,
    register,
)

#: The day frame ① is drawn on: Netflix is due « demain », Basic-Fit is « 9 jours de retard ».
TODAY = date(2026, 5, 14)


def _summary(owner: Owner, tmp_path: Path, today: date = TODAY) -> RecurringSummary:
    """Build the summary on the client's own database, anchored on a fixed ``today``."""
    session = open_session(tmp_path)
    try:
        service = RecurringService(
            RecurringRepository(session),
            TransactionRepository(session),
            AccountService(AccountRepository(session), session),
            CategoryRepository(session),
        )
        return service.summary(owner.user_id, "EUR", today)
    finally:
        session.close()


def _drawn_panel(client: TestClient, tmp_path: Path) -> tuple[Owner, str]:
    """The eight series of frame ①, plus one dismissed series that must count nowhere."""
    owner = register(client)
    account_id = create_account(client, owner)
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Netflix",
        expected_amount_minor=-1549,
        next_expected_date=date(2026, 5, 15),
        price_change_minor=-200,
        price_changed_at=date(2026, 4, 15),
    )
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Spotify Famille",
        expected_amount_minor=-1799,
        next_expected_date=date(2026, 5, 22),
        status="confirmed",
    )
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Free Mobile",
        expected_amount_minor=-1999,
        next_expected_date=date(2026, 6, 4),
        status="confirmed",
    )
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="EDF",
        expected_amount_minor=-8900,
        next_expected_date=date(2026, 6, 8),
        status="confirmed",
    )
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Basic-Fit",
        expected_amount_minor=-2999,
        next_expected_date=date(2026, 5, 5),
        status="confirmed",
    )
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Adobe Creative Cloud",
        cadence="quarterly",
        expected_amount_minor=-7199,
        next_expected_date=date(2026, 8, 2),
        status="confirmed",
    )
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="MAIF Habitation",
        cadence="yearly",
        expected_amount_minor=-18744,
        next_expected_date=date(2026, 11, 21),
        status="confirmed",
    )
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Canal+",
        expected_amount_minor=-2499,
        next_expected_date=date(2026, 4, 18),
        status="cancelled",
    )
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Deezer",
        expected_amount_minor=-1099,
        next_expected_date=date(2026, 5, 20),
        status="dismissed",
    )
    return owner, account_id


# --- monthly normalisation ------------------------------------------------------------------


def test_every_cadence_normalises_to_an_exact_integer_monthly_figure() -> None:
    # Weekly ×52/12: −10,00 € a week is −43,33 € a month, rounded once, never a float.
    assert monthly_equivalent_minor(-1000, "weekly") == -4333
    assert monthly_equivalent_minor(-1549, "monthly") == -1549
    # Quarterly ÷3: 71,99 € / 3 = 23,996… → 24,00 €.
    assert monthly_equivalent_minor(-7199, "quarterly") == -2400
    # Yearly ÷12: 187,44 € / 12 = 15,62 € exactly.
    assert monthly_equivalent_minor(-18744, "yearly") == -1562
    # A series with no period has no monthly equivalent to state.
    assert monthly_equivalent_minor(-4500, "irregular") is None


def test_a_half_unit_rounds_away_from_zero_symmetrically() -> None:
    assert monthly_equivalent_minor(-6, "yearly") == -1
    assert monthly_equivalent_minor(6, "yearly") == 1


# --- the drawn panel ------------------------------------------------------------------------


def test_the_summary_matches_the_set_the_panel_draws(client: TestClient, tmp_path: Path) -> None:
    owner, _ = _drawn_panel(client, tmp_path)

    summary = _summary(owner, tmp_path)

    # « 212,08 € », signed as an outflow (PROJECT.md §8).
    assert summary.monthly_total_minor == -21208
    assert summary.active_count == 7
    assert summary.cancelled_count == 1
    assert summary.cadence_counts == {
        "weekly": 0,
        "monthly": 5,
        "quarterly": 1,
        "yearly": 1,
        "irregular": 0,
    }
    assert summary.currency == "EUR"


def test_next_charge_is_the_soonest_one_ahead(client: TestClient, tmp_path: Path) -> None:
    owner, _ = _drawn_panel(client, tmp_path)

    next_charge = _summary(owner, tmp_path).next_charge

    # « Netflix — demain · 15,49 € · 15/05/2026 ».
    assert next_charge is not None
    assert next_charge.label == "Netflix"
    assert next_charge.amount_minor == -1549
    assert next_charge.due_on == date(2026, 5, 15)


def test_next_charge_is_null_when_no_active_series_expects_one(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Canal+",
        next_expected_date=date(2026, 4, 18),
        status="cancelled",
    )

    assert _summary(owner, tmp_path).next_charge is None


def test_a_cancelled_series_is_excluded_from_the_burden_but_still_counted(
    client: TestClient, tmp_path: Path
) -> None:
    owner, account_id = _drawn_panel(client, tmp_path)

    before = _summary(owner, tmp_path)
    session = open_session(tmp_path)
    canal = next(
        series
        for series in RecurringRepository(session).list_for_user(owner.user_id)
        if series.label == "Canal+"
    )
    session.close()

    # It is still listed — the panel dims the row rather than hiding it.
    listed = client.get("/api/v1/recurring", headers=owner.headers).json()
    assert canal.id in {series["id"] for series in listed}
    # …and its 24,99 € never entered the 212,08 €.
    assert before.monthly_total_minor == -21208
    assert before.cancelled_count == 1
    assert before.active_count == 7


def test_a_dismissed_series_counts_nowhere(client: TestClient, tmp_path: Path) -> None:
    owner, _ = _drawn_panel(client, tmp_path)

    summary = _summary(owner, tmp_path)

    assert summary.active_count + summary.cancelled_count == 8
    assert sum(summary.cadence_counts.values()) == summary.active_count


def test_an_irregular_series_is_counted_but_carries_no_burden_or_dates(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Assurance scolaire",
        cadence="irregular",
        expected_amount_minor=-4500,
        next_expected_date=date(2026, 1, 1),
        is_manual=True,
        occurrence_count=0,
    )

    summary = _summary(owner, tmp_path)

    assert summary.active_count == 1
    assert summary.cadence_counts["irregular"] == 1
    # No period to normalise from, and a placeholder date is not an expectation to miss.
    assert summary.monthly_total_minor == 0
    assert summary.next_charge is None
    assert summary.missed == []


def test_the_summary_is_scoped_to_its_user(client: TestClient, tmp_path: Path) -> None:
    owner, _ = _drawn_panel(client, tmp_path)
    other = register(client, email="bruno@example.com")

    summary = _summary(other, tmp_path)

    assert summary.monthly_total_minor == 0
    assert summary.active_count == 0
    assert summary.next_charge is None


# --- missed charges -------------------------------------------------------------------------


def test_a_missed_charge_appears_past_the_tolerance_and_reports_its_lateness(
    client: TestClient, tmp_path: Path
) -> None:
    owner, _ = _drawn_panel(client, tmp_path)

    missed = _summary(owner, tmp_path).missed

    # « Prélèvement manquant · 9 jours de retard », for the charge expected on 05/05/2026.
    assert len(missed) == 1
    assert missed[0].expected_on == date(2026, 5, 5)
    assert missed[0].days_late == 9


def test_a_charge_inside_the_cadence_tolerance_is_not_missed(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Basic-Fit",
        expected_amount_minor=-2999,
        next_expected_date=date(2026, 5, 5),
        status="confirmed",
    )

    # A monthly series tolerates ±25 % of 30 days: seven days late is a weekend, not a miss.
    assert _summary(owner, tmp_path, today=date(2026, 5, 12)).missed == []
    assert len(_summary(owner, tmp_path, today=date(2026, 5, 13)).missed) == 1


def test_a_missed_charge_disappears_when_the_transaction_is_imported_without_any_write(
    client: TestClient, tmp_path: Path
) -> None:
    owner, account_id = _drawn_panel(client, tmp_path)
    series_id = next(
        series["id"]
        for series in client.get("/api/v1/recurring", headers=owner.headers).json()
        if series["label"] == "Basic-Fit"
    )
    before = read_series(tmp_path, series_id)
    assert before is not None
    assert len(_summary(owner, tmp_path).missed) == 1

    insert_transaction(
        tmp_path,
        account_id,
        booked_date=date(2026, 5, 6),
        amount_minor=-2999,
        description="PRLV SEPA BASIC-FIT",
    )

    assert _summary(owner, tmp_path).missed == []
    after = read_series(tmp_path, series_id)
    assert after is not None
    assert (after.status, after.last_seen_date, after.next_expected_date, after.updated_at) == (
        before.status,
        before.last_seen_date,
        before.next_expected_date,
        before.updated_at,
    )


def test_an_inflow_never_clears_a_missed_charge(client: TestClient, tmp_path: Path) -> None:
    owner, account_id = _drawn_panel(client, tmp_path)
    insert_transaction(
        tmp_path,
        account_id,
        booked_date=date(2026, 5, 6),
        amount_minor=2999,
        description="PRLV SEPA BASIC-FIT",
    )

    assert len(_summary(owner, tmp_path).missed) == 1


def test_a_cancelled_series_is_never_reported_missed(client: TestClient, tmp_path: Path) -> None:
    owner, _ = _drawn_panel(client, tmp_path)

    missed = _summary(owner, tmp_path).missed

    # Canal+ is long past its next expected date; it was cancelled, not forgotten.
    assert [entry.expected_on for entry in missed] == [date(2026, 5, 5)]


# --- price increases ------------------------------------------------------------------------


def test_a_recent_increase_is_reported_with_its_signed_delta(
    client: TestClient, tmp_path: Path
) -> None:
    owner, _ = _drawn_panel(client, tmp_path)

    increases = _summary(owner, tmp_path).price_increases

    # « Augmentation · 13,49 € → 15,49 € »: on an outflow, a rise is a negative step.
    assert len(increases) == 1
    assert increases[0].delta_minor == -200
    assert increases[0].changed_at == date(2026, 4, 15)


def test_a_price_drop_is_not_an_increase(client: TestClient, tmp_path: Path) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Spotify Famille",
        expected_amount_minor=-1599,
        next_expected_date=date(2026, 5, 22),
        price_change_minor=200,
        price_changed_at=date(2026, 4, 22),
    )

    assert _summary(owner, tmp_path).price_increases == []


def test_an_increase_older_than_the_window_is_no_longer_news(
    client: TestClient, tmp_path: Path
) -> None:
    owner = register(client)
    account_id = create_account(client, owner)
    insert_series(
        tmp_path,
        owner,
        account_id,
        label="Netflix",
        expected_amount_minor=-1549,
        next_expected_date=date(2026, 5, 15),
        price_change_minor=-200,
        price_changed_at=TODAY - timedelta(days=91),
    )

    assert _summary(owner, tmp_path).price_increases == []
    assert len(_summary(owner, tmp_path, today=TODAY - timedelta(days=1)).price_increases) == 1


# --- the endpoint ---------------------------------------------------------------------------


def test_the_endpoint_returns_the_burden_and_the_counts(client: TestClient, tmp_path: Path) -> None:
    owner, _ = _drawn_panel(client, tmp_path)

    response = client.get("/api/v1/recurring/summary", headers=owner.headers)

    assert response.status_code == 200, response.json()
    body = response.json()
    assert body["monthly_total_minor"] == -21208
    assert body["active_count"] == 7
    assert body["cancelled_count"] == 1
    assert body["cadence_counts"]["monthly"] == 5
    assert body["currency"] == "EUR"
