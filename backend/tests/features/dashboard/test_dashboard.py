"""Tests for the monthly dashboard summary endpoint."""

from datetime import date
from pathlib import Path

from fastapi.testclient import TestClient

from app.features.accounts.models import Account
from app.features.dashboard.repository import DashboardRepository
from app.features.dashboard.schemas import DashboardTrends
from app.features.dashboard.service import DashboardService, divide_rounding_half_away
from app.features.imports.models import ImportBatch
from app.features.transactions.models import Transaction
from tests.api import register as _register
from tests.db import open_session

ACCOUNT_PAYLOAD = {
    "name": "Compte courant",
    "type": "checking",
    "institution": "BNP Paribas",
    "opening_balance_minor": 100_000,
}

_counter = 0


def _next_unique() -> int:
    global _counter
    _counter += 1
    return _counter


def _create_account(client: TestClient, headers: dict[str, str]) -> str:
    response = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers)
    return response.json()["id"]


def _create_category(
    client: TestClient,
    headers: dict[str, str],
    *,
    kind: str,
    name: str = "Category",
    color: str = "cat3",
    parent_id: str | None = None,
) -> str:
    response = client.post(
        "/api/v1/categories",
        json={
            "name": name,
            "kind": kind,
            "icon": "category",
            "color": color,
            "parent_id": parent_id,
        },
        headers=headers,
    )
    assert response.status_code == 201, response.text
    return response.json()["id"]


def _system_category_id(client: TestClient, headers: dict[str, str], key: str) -> str:
    response = client.get("/api/v1/categories", headers=headers)
    return next(row["id"] for row in response.json() if row["name"] == key)


def _insert_transaction(
    tmp_path: Path,
    account_id: str,
    *,
    amount_minor: int,
    booked_date: date,
    category_id: str | None = None,
) -> str:
    """Insert a transaction straight into the client's SQLite file (no import pipeline here)."""
    session = open_session(tmp_path / "test.db")
    unique = f"{_next_unique()}-{amount_minor}-{booked_date.isoformat()}"
    account = session.get(Account, account_id)
    assert account is not None
    batch = ImportBatch(
        user_id=account.user_id,
        account_id=account_id,
        source_format="ofx",
        file_name="test.ofx",
        file_hash=f"hash-{unique}",
        period_start=booked_date,
        period_end=booked_date,
        transaction_count=1,
        new_count=1,
        duplicate_count=0,
        status="success",
    )
    session.add(batch)
    session.flush()
    transaction = Transaction(
        account_id=account_id,
        import_batch_id=batch.id,
        booked_date=booked_date,
        amount_minor=amount_minor,
        currency="EUR",
        description_raw="TX",
        description_clean="TX",
        category_id=category_id,
        categorization_source="user" if category_id is not None else "uncategorized",
        needs_review=category_id is None,
        dedup_hash=f"dedup-{unique}",
    )
    session.add(transaction)
    session.commit()
    transaction_id = transaction.id
    session.close()
    return transaction_id


def _summary(client: TestClient, headers: dict[str, str], month: str) -> dict:
    response = client.get("/api/v1/dashboard/summary", params={"month": month}, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


# --- income / expense / net / savings rate ---------------------------------------------------


def test_summary_computes_income_expense_net_and_savings_rate(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    income_category = _create_category(client, headers, kind="income", name="Salaire")
    expense_category = _create_category(client, headers, kind="expense", name="Courses")

    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=300_000,
        booked_date=date(2026, 3, 5),
        category_id=income_category,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-5_000,
        booked_date=date(2026, 3, 10),
        category_id=expense_category,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-3_000,
        booked_date=date(2026, 3, 20),
        category_id=expense_category,
    )

    body = _summary(client, headers, "2026-03")

    assert body["income_minor"] == 300_000
    assert body["expense_minor"] == 8_000
    assert body["net_minor"] == 292_000
    assert body["savings_rate"] == (300_000 - 8_000) / 300_000
    assert body["currency"] == "EUR"


def test_savings_rate_is_zero_when_no_income(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    expense_category = _create_category(client, headers, kind="expense")

    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-4_000,
        booked_date=date(2026, 3, 10),
        category_id=expense_category,
    )

    body = _summary(client, headers, "2026-03")

    assert body["income_minor"] == 0
    assert body["savings_rate"] == 0.0


def test_summary_carries_the_default_savings_goal_before_settings_exist(
    client: TestClient,
) -> None:
    headers = _register(client)

    body = _summary(client, headers, "2026-03")

    assert body["savings_rate_goal_percent"] == 20


def test_summary_carries_the_users_savings_goal(client: TestClient) -> None:
    alice = _register(client, "alice@example.com")
    bob = _register(client, "bob@example.com")
    client.patch("/api/v1/settings", json={"savings_rate_goal_percent": 30}, headers=alice)

    assert _summary(client, alice, "2026-03")["savings_rate_goal_percent"] == 30
    # Another user's goal is not this one's.
    assert _summary(client, bob, "2026-03")["savings_rate_goal_percent"] == 20


def test_transfers_excluded_from_income_and_expense(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    transfer_category = _create_category(client, headers, kind="transfer", name="Virement")
    expense_category = _create_category(client, headers, kind="expense")

    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-50_000,
        booked_date=date(2026, 3, 5),
        category_id=transfer_category,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-2_000,
        booked_date=date(2026, 3, 6),
        category_id=expense_category,
    )

    body = _summary(client, headers, "2026-03")

    assert body["expense_minor"] == 2_000
    assert body["income_minor"] == 0


# --- month-over-month deltas -------------------------------------------------------------------


def test_mom_deltas_computed_against_previous_month(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    income_category = _create_category(client, headers, kind="income")
    expense_category = _create_category(client, headers, kind="expense")

    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=100_000,
        booked_date=date(2026, 2, 5),
        category_id=income_category,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-10_000,
        booked_date=date(2026, 2, 5),
        category_id=expense_category,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=150_000,
        booked_date=date(2026, 3, 5),
        category_id=income_category,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-15_000,
        booked_date=date(2026, 3, 5),
        category_id=expense_category,
    )

    body = _summary(client, headers, "2026-03")

    assert body["income_delta_pct"] == (150_000 - 100_000) / 100_000 * 100
    assert body["expense_delta_pct"] == (15_000 - 10_000) / 10_000 * 100

    prev_net = 100_000 - 10_000
    current_net = 150_000 - 15_000
    assert body["net_delta_pct"] == (current_net - prev_net) / prev_net * 100

    prev_rate = (100_000 - 10_000) / 100_000
    current_rate = (150_000 - 15_000) / 150_000
    assert body["savings_rate_delta_pct"] == (current_rate - prev_rate) * 100


def test_net_delta_keeps_its_sign_when_the_previous_month_was_negative(
    client: TestClient, tmp_path: Path
) -> None:
    """A month recovering from a loss reads as a rise, not a fall.

    Dividing by a signed negative baseline would invert the sign and make the dashboard's trend
    pill report an improvement as a red, downward move.
    """
    headers = _register(client)
    account_id = _create_account(client, headers)
    income_category = _create_category(client, headers, kind="income")
    expense_category = _create_category(client, headers, kind="expense")

    # February ends at −20 000 minor units: income 10 000, expense 30 000.
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=10_000,
        booked_date=date(2026, 2, 5),
        category_id=income_category,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-30_000,
        booked_date=date(2026, 2, 5),
        category_id=expense_category,
    )
    # March recovers to +40 000.
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=50_000,
        booked_date=date(2026, 3, 5),
        category_id=income_category,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-10_000,
        booked_date=date(2026, 3, 5),
        category_id=expense_category,
    )

    body = _summary(client, headers, "2026-03")

    assert body["net_minor"] == 40_000
    # (40 000 − −20 000) / |−20 000| × 100 — a rise, positive.
    assert body["net_delta_pct"] == 300.0


def test_net_delta_is_negative_when_a_loss_deepens(client: TestClient, tmp_path: Path) -> None:
    """The mirror of the recovery case: a worsening loss must still read as a fall."""
    headers = _register(client)
    account_id = _create_account(client, headers)
    income_category = _create_category(client, headers, kind="income")
    expense_category = _create_category(client, headers, kind="expense")

    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=10_000,
        booked_date=date(2026, 2, 5),
        category_id=income_category,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-30_000,
        booked_date=date(2026, 2, 5),
        category_id=expense_category,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=10_000,
        booked_date=date(2026, 3, 5),
        category_id=income_category,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-50_000,
        booked_date=date(2026, 3, 5),
        category_id=expense_category,
    )

    body = _summary(client, headers, "2026-03")

    assert body["net_minor"] == -40_000
    # (−40 000 − −20 000) / |−20 000| × 100.
    assert body["net_delta_pct"] == -100.0


def test_mom_delta_is_safe_when_previous_month_is_absent(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    income_category = _create_category(client, headers, kind="income")

    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=100_000,
        booked_date=date(2026, 3, 5),
        category_id=income_category,
    )

    body = _summary(client, headers, "2026-03")

    assert body["income_delta_pct"] == 0.0
    assert body["expense_delta_pct"] == 0.0
    assert body["net_delta_pct"] == 0.0
    assert body["savings_rate_delta_pct"] == 0.0


# --- by-category breakdown ----------------------------------------------------------------------


def test_by_category_breakdown_sums_to_expense_total_and_pcts_sum_to_100(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    groceries = _create_category(client, headers, kind="expense", name="Courses")
    transport = _create_category(client, headers, kind="expense", name="Transport")

    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-6_000,
        booked_date=date(2026, 3, 5),
        category_id=groceries,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-4_000,
        booked_date=date(2026, 3, 6),
        category_id=transport,
    )

    body = _summary(client, headers, "2026-03")

    assert body["expense_minor"] == 10_000
    assert sum(row["amount_minor"] for row in body["by_category"]) == body["expense_minor"]
    assert round(sum(row["pct"] for row in body["by_category"])) == 100

    by_name = {row["category_id"]: row["pct"] for row in body["by_category"]}
    assert by_name[groceries] == 60.0
    assert by_name[transport] == 40.0


def test_uncategorized_expenses_are_bucketed_and_counted(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    groceries = _create_category(client, headers, kind="expense", name="Courses")

    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-6_000,
        booked_date=date(2026, 3, 5),
        category_id=groceries,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-4_000,
        booked_date=date(2026, 3, 6),
        category_id=None,
    )

    body = _summary(client, headers, "2026-03")

    assert body["expense_minor"] == 10_000
    uncategorized = next(row for row in body["by_category"] if row["category_id"] is None)
    assert uncategorized["amount_minor"] == 4_000
    assert uncategorized["name"] == "category.other.uncategorized"
    assert sum(row["amount_minor"] for row in body["by_category"]) == body["expense_minor"]


def test_subcategory_spending_rolls_up_to_its_top_level_category(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    hobbies = _create_category(client, headers, kind="expense", name="Atelier", color="cat5")
    paint = _create_category(
        client, headers, kind="expense", name="Peinture", color="cat5", parent_id=hobbies
    )
    wood = _create_category(
        client, headers, kind="expense", name="Bois", color="cat5", parent_id=hobbies
    )

    for amount, category in ((-1_250, hobbies), (-2_500, paint), (-3_750, wood)):
        _insert_transaction(
            tmp_path,
            account_id,
            amount_minor=amount,
            booked_date=date(2026, 3, 5),
            category_id=category,
        )

    body = _summary(client, headers, "2026-03")

    assert body["by_category"] == [
        {
            "category_id": hobbies,
            "name": "Atelier",
            "hue": "cat5",
            "amount_minor": 7_500,
            "pct": 100.0,
        }
    ]


def test_system_subcategories_roll_up_to_their_bucket_with_its_hue(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    housing = _system_category_id(client, headers, "category.housing")
    rent = _system_category_id(client, headers, "category.housing.rent")
    utilities = _system_category_id(client, headers, "category.housing.utilities")

    _insert_transaction(
        tmp_path, account_id, amount_minor=-50_000, booked_date=date(2026, 3, 1), category_id=rent
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-8_000,
        booked_date=date(2026, 3, 9),
        category_id=utilities,
    )

    body = _summary(client, headers, "2026-03")

    [row] = body["by_category"]
    assert row["category_id"] == housing
    assert row["name"] == "category.housing"
    assert row["hue"] == "cat1"
    assert row["amount_minor"] == 58_000


def test_custom_top_level_category_carries_its_own_hue(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    garden = _create_category(client, headers, kind="expense", name="Jardin", color="cat6")
    plain = _create_category(client, headers, kind="expense", name="Divers", color="cat0")

    _insert_transaction(
        tmp_path, account_id, amount_minor=-3_000, booked_date=date(2026, 3, 2), category_id=garden
    )
    _insert_transaction(
        tmp_path, account_id, amount_minor=-1_000, booked_date=date(2026, 3, 3), category_id=plain
    )
    _insert_transaction(
        tmp_path, account_id, amount_minor=-500, booked_date=date(2026, 3, 4), category_id=None
    )

    body = _summary(client, headers, "2026-03")

    hues = {row["category_id"]: row["hue"] for row in body["by_category"]}
    assert hues == {garden: "cat6", plain: "cat0", None: "cat0"}


# --- scoping & validation ------------------------------------------------------------------------


def test_summary_requires_auth(client: TestClient) -> None:
    response = client.get("/api/v1/dashboard/summary", params={"month": "2026-03"})
    assert response.status_code == 401


def test_summary_is_user_scoped(client: TestClient, tmp_path: Path) -> None:
    headers_a = _register(client, "amelie@example.com")
    account_id_a = _create_account(client, headers_a)
    income_category_a = _create_category(client, headers_a, kind="income")
    _insert_transaction(
        tmp_path,
        account_id_a,
        amount_minor=100_000,
        booked_date=date(2026, 3, 5),
        category_id=income_category_a,
    )

    headers_b = _register(client, "bruno@example.com")
    account_id_b = _create_account(client, headers_b)
    income_category_b = _create_category(client, headers_b, kind="income")
    _insert_transaction(
        tmp_path,
        account_id_b,
        amount_minor=500_000,
        booked_date=date(2026, 3, 5),
        category_id=income_category_b,
    )

    body = _summary(client, headers_a, "2026-03")
    assert body["income_minor"] == 100_000


def test_summary_rejects_invalid_month(client: TestClient) -> None:
    headers = _register(client)
    response = client.get("/api/v1/dashboard/summary", params={"month": "2026-13"}, headers=headers)
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "DASHBOARD_MONTH_INVALID"


# --- trend series ---------------------------------------------------------------------------


def _trends_service(
    client: TestClient,
    headers: dict[str, str],
    tmp_path: Path,
    today: date,
    month: str | None = None,
) -> DashboardTrends:
    """Call the service directly so the series can be anchored on a fixed `today`.

    The endpoint reads the real clock, which would make every assertion below expire the
    moment the calendar moved on. The session is opened on the client's own SQLite file, the
    same way `_insert_transaction` does.
    """
    user = client.get("/api/v1/auth/me", headers=headers).json()["user"]
    session = open_session(tmp_path / "test.db")
    try:
        service = DashboardService(DashboardRepository(session))
        return service.trends(user["id"], user["currency"], today, month)
    finally:
        session.close()


def test_trends_returns_four_bar_months_and_twelve_savings_months(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    income_category = _create_category(client, headers, kind="income")

    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=100_000,
        booked_date=date(2026, 5, 5),
        category_id=income_category,
    )

    trends = _trends_service(client, headers, tmp_path, date(2026, 5, 20))

    assert [row.month for row in trends.monthly_series] == [
        "2026-02",
        "2026-03",
        "2026-04",
        "2026-05",
    ]
    assert [row.month for row in trends.savings_series] == [
        "2025-06",
        "2025-07",
        "2025-08",
        "2025-09",
        "2025-10",
        "2025-11",
        "2025-12",
        "2026-01",
        "2026-02",
        "2026-03",
        "2026-04",
        "2026-05",
    ]
    assert trends.currency == "EUR"


def test_trends_windows_end_at_today_without_a_month(client: TestClient, tmp_path: Path) -> None:
    """Without a month the series end on the calendar's, crossing a year boundary correctly."""
    headers = _register(client)
    _create_account(client, headers)

    trends = _trends_service(client, headers, tmp_path, date(2026, 2, 3))

    assert [row.month for row in trends.monthly_series] == [
        "2025-11",
        "2025-12",
        "2026-01",
        "2026-02",
    ]
    assert trends.savings_series[0].month == "2025-03"


def test_trends_bars_carry_income_expense_and_net_per_month(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    income_category = _create_category(client, headers, kind="income")
    expense_category = _create_category(client, headers, kind="expense")

    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=285_000,
        booked_date=date(2026, 5, 2),
        category_id=income_category,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-221_435,
        booked_date=date(2026, 5, 14),
        category_id=expense_category,
    )

    trends = _trends_service(client, headers, tmp_path, date(2026, 5, 20))
    may = trends.monthly_series[-1]

    assert may.income_minor == 285_000
    # Expense is the positive magnitude, matching the summary's convention.
    assert may.expense_minor == 221_435
    assert may.net_minor == 63_565

    # A month with no transactions is a zero bar, not a missing one.
    assert trends.monthly_series[0].income_minor == 0
    assert trends.monthly_series[0].net_minor == 0


def test_savings_series_carries_each_months_own_net(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    income_category = _create_category(client, headers, kind="income")
    expense_category = _create_category(client, headers, kind="expense")

    # Before the 12-month window: counted nowhere, since no point is a running total.
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=500_000,
        booked_date=date(2025, 5, 1),
        category_id=income_category,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-40_000,
        booked_date=date(2026, 3, 9),
        category_id=expense_category,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=100_000,
        booked_date=date(2026, 4, 1),
        category_id=income_category,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=63_565,
        booked_date=date(2026, 5, 1),
        category_id=income_category,
    )

    trends = _trends_service(client, headers, tmp_path, date(2026, 5, 20))
    saved = [row.saved_minor for row in trends.savings_series]

    # Each month stands alone — one that spent more than it earned is negative.
    assert saved == [0] * 9 + [-40_000, 100_000, 63_565]


def test_trends_excludes_transfers(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    transfer_category = _create_category(client, headers, kind="transfer", name="Virement")

    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=-50_000,
        booked_date=date(2026, 5, 5),
        category_id=transfer_category,
    )

    trends = _trends_service(client, headers, tmp_path, date(2026, 5, 20))

    assert trends.monthly_series[-1].expense_minor == 0
    assert trends.savings_series[-1].saved_minor == 0


def test_trends_is_user_scoped(client: TestClient, tmp_path: Path) -> None:
    headers_a = _register(client, "amelie@example.com")
    account_id_a = _create_account(client, headers_a)
    income_a = _create_category(client, headers_a, kind="income")
    _insert_transaction(
        tmp_path,
        account_id_a,
        amount_minor=100_000,
        booked_date=date(2026, 5, 5),
        category_id=income_a,
    )

    headers_b = _register(client, "bruno@example.com")
    account_id_b = _create_account(client, headers_b)
    income_b = _create_category(client, headers_b, kind="income")
    _insert_transaction(
        tmp_path,
        account_id_b,
        amount_minor=500_000,
        booked_date=date(2026, 5, 5),
        category_id=income_b,
    )

    trends = _trends_service(client, headers_a, tmp_path, date(2026, 5, 20))

    assert trends.monthly_series[-1].income_minor == 100_000


def test_trends_requires_auth(client: TestClient) -> None:
    response = client.get("/api/v1/dashboard/trends")
    assert response.status_code == 401


def test_trends_savings_window_ends_on_the_requested_month(
    client: TestClient, tmp_path: Path
) -> None:
    """An earlier month moves the savings window back; the monthly bars stay on the calendar."""
    headers = _register(client)
    account_id = _create_account(client, headers)
    income_category = _create_category(client, headers, kind="income")
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=42_000,
        booked_date=date(2025, 11, 8),
        category_id=income_category,
    )
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=31_000,
        booked_date=date(2026, 5, 4),
        category_id=income_category,
    )

    trends = _trends_service(client, headers, tmp_path, date(2026, 5, 20), month="2025-11")

    assert trends.savings_series[0].month == "2024-12"
    assert trends.savings_series[-1].month == "2025-11"
    assert len(trends.savings_series) == 12
    assert trends.savings_series[-1].saved_minor == 42_000
    assert [row.month for row in trends.monthly_series] == [
        "2026-02",
        "2026-03",
        "2026-04",
        "2026-05",
    ]
    assert trends.monthly_series[-1].income_minor == 31_000


def test_trends_monthly_bars_ignore_a_later_month(client: TestClient, tmp_path: Path) -> None:
    """Even a month past today leaves the bars ending on the current month."""
    headers = _register(client)
    _create_account(client, headers)

    trends = _trends_service(client, headers, tmp_path, date(2026, 5, 20), month="2026-08")

    assert trends.savings_series[-1].month == "2026-08"
    assert trends.monthly_series[-1].month == "2026-05"


def test_trends_endpoint_honours_the_month_parameter(client: TestClient) -> None:
    headers = _register(client)

    response = client.get("/api/v1/dashboard/trends", params={"month": "2020-01"}, headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert body["savings_series"][0]["month"] == "2019-02"
    assert body["savings_series"][-1]["month"] == "2020-01"
    assert body["monthly_series"][-1]["month"] == date.today().strftime("%Y-%m")


def test_trends_endpoint_defaults_to_the_current_month(client: TestClient) -> None:
    headers = _register(client)

    response = client.get("/api/v1/dashboard/trends", headers=headers)

    assert response.status_code == 200
    assert response.json()["savings_series"][-1]["month"] == date.today().strftime("%Y-%m")


def test_trends_rejects_invalid_month(client: TestClient) -> None:
    headers = _register(client)

    out_of_range = client.get(
        "/api/v1/dashboard/trends", params={"month": "2026-13"}, headers=headers
    )
    malformed = client.get("/api/v1/dashboard/trends", params={"month": "May"}, headers=headers)

    assert out_of_range.status_code == 422
    assert out_of_range.json()["error"]["code"] == "DASHBOARD_MONTH_INVALID"
    assert malformed.status_code == 422


# --- habits: each category's month against its 12-month average -----------------------------


def _habits(client: TestClient, headers: dict[str, str], month: str) -> dict:
    response = client.get("/api/v1/dashboard/habits", params={"month": month}, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def _row(body: dict, category_id: str | None) -> dict:
    return next(row for row in body["rows"] if row["category_id"] == category_id)


def _spend(
    tmp_path: Path, account_id: str, amount: int, day: date, category_id: str | None = None
) -> None:
    """Insert an outflow of `amount` minor units (given as a positive magnitude)."""
    _insert_transaction(
        tmp_path, account_id, amount_minor=-amount, booked_date=day, category_id=category_id
    )


def test_habits_averages_the_twelve_months_before_the_selected_one(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    groceries = _create_category(client, headers, kind="expense", name="Courses")

    # Thirteen months back: outside the window, so it must not weigh on the average.
    _spend(tmp_path, account_id, 900_000, date(2025, 4, 3), groceries)
    # 2025-05 … 2026-04: 10 000 a month, except one month at 22 000 → 132 000 / 12 = 11 000.
    for offset in range(12):
        year, month = (2025, 5 + offset) if offset < 8 else (2026, offset - 7)
        _spend(
            tmp_path,
            account_id,
            22_000 if offset == 3 else 10_000,
            date(year, month, 12),
            groceries,
        )
    # The selected month itself: a spike that must not soften its own gap.
    _spend(tmp_path, account_id, 15_000, date(2026, 5, 8), groceries)

    body = _habits(client, headers, "2026-05")

    assert body["month"] == "2026-05"
    assert body["months_counted"] == 12
    assert body["currency"] == "EUR"
    row = _row(body, groceries)
    assert row["name"] == "Courses"
    assert row["hue"] == "cat3"
    assert row["amount_minor"] == 15_000
    assert row["average_minor"] == 11_000
    assert row["gap_minor"] == 4_000
    assert body["total_gap_minor"] == 4_000
    assert all(type(row[key]) is int for key in ("amount_minor", "average_minor", "gap_minor"))


def test_habits_averages_only_the_months_a_newer_user_has(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    groceries = _create_category(client, headers, kind="expense", name="Courses")
    salary = _create_category(client, headers, kind="income", name="Salaire")

    # The user's first transaction, an income, opens the counted range in 2026-02.
    _insert_transaction(
        tmp_path, account_id, amount_minor=250_000, booked_date=date(2026, 2, 1), category_id=salary
    )
    # 2026-03 has no groceries: it still counts, as zero.
    _spend(tmp_path, account_id, 6_000, date(2026, 2, 14), groceries)
    _spend(tmp_path, account_id, 3_000, date(2026, 4, 14), groceries)
    _spend(tmp_path, account_id, 2_000, date(2026, 5, 2), groceries)

    body = _habits(client, headers, "2026-05")

    assert body["months_counted"] == 3
    row = _row(body, groceries)
    assert row["average_minor"] == 3_000  # 9 000 over 3 months
    assert row["gap_minor"] == -1_000
    assert body["total_gap_minor"] == -1_000


def test_habits_category_without_history_has_no_average(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    groceries = _create_category(client, headers, kind="expense", name="Courses")
    travel = _create_category(client, headers, kind="expense", name="Voyages", color="cat5")

    _spend(tmp_path, account_id, 4_000, date(2026, 4, 10), groceries)
    _spend(tmp_path, account_id, 5_000, date(2026, 5, 10), groceries)
    # A large first-ever spend in a category: no history, so no average and no gap.
    _spend(tmp_path, account_id, 80_000, date(2026, 5, 11), travel)

    body = _habits(client, headers, "2026-05")

    row = _row(body, travel)
    assert row["amount_minor"] == 80_000
    assert row["average_minor"] is None
    assert row["gap_minor"] is None
    # Placed after the rows that have a gap, and left out of the total.
    assert [row["category_id"] for row in body["rows"]] == [groceries, travel]
    assert body["total_gap_minor"] == 1_000


def test_habits_first_month_of_data_has_no_averages_and_no_total(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    groceries = _create_category(client, headers, kind="expense", name="Courses")
    _spend(tmp_path, account_id, 5_000, date(2026, 5, 10), groceries)

    body = _habits(client, headers, "2026-05")

    assert body["months_counted"] == 0
    assert _row(body, groceries)["average_minor"] is None
    assert body["total_gap_minor"] is None


def test_habits_average_rounds_halves_away_from_zero(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    groceries = _create_category(client, headers, kind="expense", name="Courses")
    _spend(tmp_path, account_id, 1_000, date(2026, 3, 10), groceries)
    _spend(tmp_path, account_id, 1_001, date(2026, 4, 10), groceries)
    _spend(tmp_path, account_id, 2_000, date(2026, 5, 10), groceries)

    body = _habits(client, headers, "2026-05")

    row = _row(body, groceries)
    assert row["average_minor"] == 1_001  # 2 001 / 2 = 1 000.5 → 1 001
    assert row["gap_minor"] == 999


def test_divide_rounding_half_away_is_symmetric_and_exact() -> None:
    assert divide_rounding_half_away(3, 2) == 2  # 1.5 → 2
    assert divide_rounding_half_away(-3, 2) == -2  # −1.5 → −2
    assert divide_rounding_half_away(31, 3) == 10  # 10.33 → 10
    assert divide_rounding_half_away(32, 3) == 11  # 10.67 → 11
    assert divide_rounding_half_away(-32, 3) == -11
    assert divide_rounding_half_away(-31, 3) == -10
    big = 2**53 + 1  # a float would round this off
    assert divide_rounding_half_away(big * 2, 2) == big


def test_habits_excludes_transfers(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    groceries = _create_category(client, headers, kind="expense", name="Courses")
    transfer = _create_category(client, headers, kind="transfer", name="Virement")
    _spend(tmp_path, account_id, 50_000, date(2026, 4, 1), transfer)
    _spend(tmp_path, account_id, 3_000, date(2026, 4, 9), groceries)
    _spend(tmp_path, account_id, 70_000, date(2026, 5, 1), transfer)
    _spend(tmp_path, account_id, 3_000, date(2026, 5, 9), groceries)

    body = _habits(client, headers, "2026-05")

    assert [row["category_id"] for row in body["rows"]] == [groceries]
    assert _row(body, groceries)["average_minor"] == 3_000
    assert body["total_gap_minor"] == 0


def test_habits_month_with_no_spending_has_no_rows(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    groceries = _create_category(client, headers, kind="expense", name="Courses")
    salary = _create_category(client, headers, kind="income", name="Salaire")
    _spend(tmp_path, account_id, 4_000, date(2026, 3, 10), groceries)
    # Income only in the selected month: not spending.
    _insert_transaction(
        tmp_path, account_id, amount_minor=250_000, booked_date=date(2026, 5, 1), category_id=salary
    )

    body = _habits(client, headers, "2026-05")

    assert body["months_counted"] == 2
    assert body["rows"] == []
    assert body["total_gap_minor"] is None


def test_habits_rolls_up_subcategories_and_buckets_uncategorised(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    food = _create_category(client, headers, kind="expense", name="Alimentation")
    bakery = _create_category(client, headers, kind="expense", name="Boulangerie", parent_id=food)
    _spend(tmp_path, account_id, 2_000, date(2026, 4, 10), food)
    _spend(tmp_path, account_id, 1_000, date(2026, 5, 10), food)
    _spend(tmp_path, account_id, 1_500, date(2026, 5, 11), bakery)
    _spend(tmp_path, account_id, 700, date(2026, 4, 12))
    _spend(tmp_path, account_id, 300, date(2026, 5, 12))
    _spend(tmp_path, account_id, 200, date(2026, 5, 13))

    body = _habits(client, headers, "2026-05")

    food_row = _row(body, food)
    assert food_row["amount_minor"] == 2_500
    assert food_row["average_minor"] == 2_000
    uncategorised = _row(body, None)
    assert uncategorised["name"] == "category.other.uncategorized"
    assert uncategorised["hue"] == "cat0"
    assert uncategorised["amount_minor"] == 500
    assert uncategorised["gap_minor"] == -200
    # One row per top-level bucket, by the size of the gap.
    assert [row["category_id"] for row in body["rows"]] == [food, None]
    assert body["total_gap_minor"] == 300


def test_habits_orders_rows_by_gap_size_rises_and_falls_mixed(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    small_rise = _create_category(client, headers, kind="expense", name="A")
    big_fall = _create_category(client, headers, kind="expense", name="B")
    mid_rise = _create_category(client, headers, kind="expense", name="C")
    for category_id, before, now in (
        (small_rise, 1_000, 1_100),
        (big_fall, 9_000, 1_000),
        (mid_rise, 1_000, 4_000),
    ):
        _spend(tmp_path, account_id, before, date(2026, 4, 10), category_id)
        _spend(tmp_path, account_id, now, date(2026, 5, 10), category_id)

    body = _habits(client, headers, "2026-05")

    assert [row["category_id"] for row in body["rows"]] == [big_fall, mid_rise, small_rise]
    assert body["total_gap_minor"] == -8_000 + 3_000 + 100


def test_habits_is_user_scoped(client: TestClient, tmp_path: Path) -> None:
    alice = _register(client, "amelie@example.com")
    bob = _register(client, "bruno@example.com")
    account_a = _create_account(client, alice)
    account_b = _create_account(client, bob)
    groceries_a = _create_category(client, alice, kind="expense", name="Courses")
    groceries_b = _create_category(client, bob, kind="expense", name="Courses")
    _spend(tmp_path, account_a, 1_000, date(2026, 5, 10), groceries_a)
    # Bob's earlier history must neither open Alice's counted range nor appear in her rows.
    _spend(tmp_path, account_b, 9_000, date(2026, 1, 10), groceries_b)
    _spend(tmp_path, account_b, 9_000, date(2026, 5, 10), groceries_b)

    body = _habits(client, alice, "2026-05")

    assert body["months_counted"] == 0
    assert [row["category_id"] for row in body["rows"]] == [groceries_a]


def test_habits_requires_auth(client: TestClient) -> None:
    response = client.get("/api/v1/dashboard/habits", params={"month": "2026-05"})
    assert response.status_code == 401


def test_habits_rejects_invalid_month(client: TestClient) -> None:
    headers = _register(client)
    response = client.get("/api/v1/dashboard/habits", params={"month": "2026-13"}, headers=headers)
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "DASHBOARD_MONTH_INVALID"
