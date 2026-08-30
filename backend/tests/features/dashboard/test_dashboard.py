"""Tests for the monthly dashboard summary endpoint."""

from datetime import date
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.features.accounts.models import Account
from app.features.dashboard.repository import DashboardRepository
from app.features.dashboard.schemas import DashboardTrends
from app.features.dashboard.service import DashboardService
from app.features.imports.models import ImportBatch
from app.features.transactions.models import Transaction

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


def _create_account(client: TestClient, headers: dict[str, str]) -> str:
    response = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers)
    return response.json()["id"]


def _create_category(
    client: TestClient, headers: dict[str, str], *, kind: str, name: str = "Category"
) -> str:
    response = client.post(
        "/api/v1/categories",
        json={"name": name, "kind": kind, "icon": "category", "color": "#10B981"},
        headers=headers,
    )
    return response.json()["id"]


def _insert_transaction(
    tmp_path: Path,
    account_id: str,
    *,
    amount_minor: int,
    booked_date: date,
    category_id: str | None = None,
) -> str:
    """Insert a transaction straight into the client's SQLite file (no import pipeline here)."""
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}", connect_args={"check_same_thread": False}
    )
    session = sessionmaker(bind=engine)()
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
    client: TestClient, headers: dict[str, str], tmp_path: Path, today: date
) -> DashboardTrends:
    """Call the service directly so the series can be anchored on a fixed `today`.

    The endpoint reads the real clock, which would make every assertion below expire the
    moment the calendar moved on. The session is opened on the client's own SQLite file, the
    same way `_insert_transaction` does.
    """
    user = client.get("/api/v1/auth/me", headers=headers).json()["user"]
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}", connect_args={"check_same_thread": False}
    )
    session = sessionmaker(bind=engine)()
    try:
        service = DashboardService(DashboardRepository(session))
        return service.trends(user["id"], user["currency"], today)
    finally:
        session.close()


def test_trends_returns_four_bar_months_and_six_savings_months(
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
        "2025-12",
        "2026-01",
        "2026-02",
        "2026-03",
        "2026-04",
        "2026-05",
    ]
    assert trends.currency == "EUR"


def test_trends_windows_ignore_the_selected_month_and_end_at_today(
    client: TestClient, tmp_path: Path
) -> None:
    """The series are anchored on the calendar, so they cross a year boundary correctly."""
    headers = _register(client)
    _create_account(client, headers)

    trends = _trends_service(client, headers, tmp_path, date(2026, 2, 3))

    assert [row.month for row in trends.monthly_series] == [
        "2025-11",
        "2025-12",
        "2026-01",
        "2026-02",
    ]
    assert trends.savings_series[0].month == "2025-09"


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


def test_savings_series_accumulates_and_opens_from_prior_months(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client)
    account_id = _create_account(client, headers)
    income_category = _create_category(client, headers, kind="income")

    # Before the 6-month window — must still be counted, or the line understates the total.
    _insert_transaction(
        tmp_path,
        account_id,
        amount_minor=500_000,
        booked_date=date(2025, 6, 1),
        category_id=income_category,
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
    cumulative = [row.cumulative_minor for row in trends.savings_series]

    # Opens at the pre-window total, then only ever moves by that month's net.
    assert cumulative == [500_000, 500_000, 500_000, 500_000, 600_000, 663_565]


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
    assert trends.savings_series[-1].cumulative_minor == 0


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


def test_trends_endpoint_takes_no_month_parameter(client: TestClient) -> None:
    """A stray `?month=` is ignored rather than honoured — the window is the calendar's."""
    headers = _register(client)

    plain = client.get("/api/v1/dashboard/trends", headers=headers)
    with_month = client.get(
        "/api/v1/dashboard/trends", params={"month": "2020-01"}, headers=headers
    )

    assert plain.status_code == 200
    assert with_month.status_code == 200
    assert plain.json() == with_month.json()
