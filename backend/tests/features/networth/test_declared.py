"""Tests for declared month-end totals: the endpoints, and how the series reads them.

What is at stake is that a declared total fills only the months the ledger cannot: it never
outranks an imported figure, never adds to one, and is never accepted for a month still running.
"""

from datetime import date

from fastapi.testclient import TestClient

from tests.api import register
from tests.features.networth.test_networth import (
    LOAN_SCHEDULE,
    add_snapshot,
    create_account,
    create_loan,
    create_property,
    summary,
)

DECLARED = "/api/v1/networth/declared"


def declare(client: TestClient, headers: dict[str, str], month: str, amount: int) -> dict:
    response = client.put(f"{DECLARED}/{month}", json={"amount_minor": amount}, headers=headers)
    assert response.status_code == 200, response.json()
    return dict(response.json())


def listed(client: TestClient, headers: dict[str, str]) -> list[dict]:
    response = client.get(DECLARED, headers=headers)
    assert response.status_code == 200, response.json()
    return list(response.json())


# --- the endpoints ---------------------------------------------------------------------------


def test_a_declared_total_is_listed_oldest_first(client: TestClient) -> None:
    headers = register(client)

    created = declare(client, headers, "2025-03", 812_345)
    declare(client, headers, "2024-11", -15_000)

    assert created == {
        "month": "2025-03",
        "amount_minor": 812_345,
        "currency": "EUR",
        "superseded": False,
    }
    assert listed(client, headers) == [
        {"month": "2024-11", "amount_minor": -15_000, "currency": "EUR", "superseded": False},
        {"month": "2025-03", "amount_minor": 812_345, "currency": "EUR", "superseded": False},
    ]


def test_declaring_a_month_again_replaces_its_total(client: TestClient) -> None:
    headers = register(client)
    declare(client, headers, "2025-03", 800_000)

    declare(client, headers, "2025-03", 805_000)

    assert [row["amount_minor"] for row in listed(client, headers)] == [805_000]


def test_money_stays_integer(client: TestClient) -> None:
    headers = register(client)
    declare(client, headers, "2025-03", 812_345)

    (row,) = listed(client, headers)
    (point,) = summary(client, headers)["series"]

    assert type(row["amount_minor"]) is int
    assert type(point["net_worth_minor"]) is int


def test_a_float_amount_is_refused(client: TestClient) -> None:
    headers = register(client)

    response = client.put(f"{DECLARED}/2025-03", json={"amount_minor": 12.5}, headers=headers)

    assert response.status_code == 422


def test_the_current_month_is_refused(client: TestClient) -> None:
    """Today is pinned to 2026-05-15 by the net-worth tests' autouse fixture."""
    headers = register(client)

    for month in ("2026-05", "2026-06"):
        response = client.put(f"{DECLARED}/{month}", json={"amount_minor": 1}, headers=headers)
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "DECLARED_MONTH_NOT_CLOSED"
    assert listed(client, headers) == []


def test_a_malformed_month_is_refused(client: TestClient) -> None:
    headers = register(client)

    for month in ("2025-13", "2025-3", "march"):
        response = client.put(f"{DECLARED}/{month}", json={"amount_minor": 1}, headers=headers)
        assert response.status_code == 422, month


def test_a_declared_total_can_be_removed(client: TestClient) -> None:
    headers = register(client)
    declare(client, headers, "2025-03", 800_000)

    assert client.delete(f"{DECLARED}/2025-03", headers=headers).status_code == 204
    assert listed(client, headers) == []

    again = client.delete(f"{DECLARED}/2025-03", headers=headers)
    assert again.status_code == 404
    assert again.json()["error"]["code"] == "DECLARED_BALANCE_NOT_FOUND"


def test_a_month_the_ledger_covers_is_flagged_superseded(client: TestClient) -> None:
    headers = register(client)
    account = create_account(client, headers, 0)
    add_snapshot(client, account["id"], date(2026, 1, 31), 900_000)

    declare(client, headers, "2025-12", 850_000)
    covered = declare(client, headers, "2026-01", 1)

    assert covered["superseded"] is True
    assert [row["superseded"] for row in listed(client, headers)] == [False, True]


def test_declared_totals_are_scoped_to_the_caller(client: TestClient) -> None:
    owner = register(client)
    other = register(client, "bruno@example.com")
    declare(client, owner, "2025-03", 800_000)

    assert listed(client, other) == []
    assert summary(client, other)["series"] == []
    assert client.delete(f"{DECLARED}/2025-03", headers=other).status_code == 404
    assert len(listed(client, owner)) == 1


def test_anonymous_requests_are_refused(client: TestClient) -> None:
    assert client.get(DECLARED).status_code == 401
    assert client.put(f"{DECLARED}/2025-03", json={"amount_minor": 1}).status_code == 401
    assert client.delete(f"{DECLARED}/2025-03").status_code == 401


# --- the series ------------------------------------------------------------------------------


def test_declared_months_extend_the_series_before_the_ledger(client: TestClient) -> None:
    headers = register(client)
    account = create_account(client, headers, 0)
    add_snapshot(client, account["id"], date(2026, 3, 31), 1_050_000)
    add_snapshot(client, account["id"], date(2026, 4, 30), 1_120_000)
    declare(client, headers, "2024-01", 600_000)
    declare(client, headers, "2026-02", 1_000_000)

    assert summary(client, headers)["series"] == [
        {"month": "2024-01", "net_worth_minor": 600_000, "source": "declared"},
        {"month": "2026-02", "net_worth_minor": 1_000_000, "source": "declared"},
        {"month": "2026-03", "net_worth_minor": 1_050_000, "source": "ledger"},
        {"month": "2026-04", "net_worth_minor": 1_120_000, "source": "ledger"},
    ]


def test_the_ledger_wins_over_a_declared_total_and_is_never_added_to_it(
    client: TestClient,
) -> None:
    headers = register(client)
    account = create_account(client, headers, 0)
    add_snapshot(client, account["id"], date(2026, 3, 31), 1_050_000)
    declare(client, headers, "2026-03", 999_999)

    assert summary(client, headers)["series"] == [
        {"month": "2026-03", "net_worth_minor": 1_050_000, "source": "ledger"}
    ]


def test_a_declared_total_stands_for_the_accounts_only(client: TestClient) -> None:
    """The property is held flat and the loan follows its schedule, as on a ledger month."""
    headers = register(client)
    create_property(client, headers)
    create_loan(client, headers)
    declare(client, headers, "2025-06", 2_000_000)

    (point,) = summary(client, headers)["series"]

    assert point == {
        "month": "2025-06",
        "net_worth_minor": 2_000_000 + 42_000_000 - LOAN_SCHEDULE.outstanding_at(date(2025, 6, 30)),
        "source": "declared",
    }


def test_the_month_delta_spans_the_declared_to_ledger_handover(client: TestClient) -> None:
    headers = register(client)
    account = create_account(client, headers, 0)
    add_snapshot(client, account["id"], date(2026, 4, 30), 1_120_000)
    declare(client, headers, "2026-03", 1_000_000)

    assert summary(client, headers)["month_delta_minor"] == 120_000


# --- backup ----------------------------------------------------------------------------------


def test_a_backup_carries_the_declared_totals(client: TestClient) -> None:
    headers = register(client)
    declare(client, headers, "2025-03", 812_345)
    archive = client.post("/api/v1/backup/export", headers=headers)
    assert archive.status_code == 200
    client.delete(f"{DECLARED}/2025-03", headers=headers)

    restored = client.post(
        "/api/v1/backup/restore",
        headers=headers,
        files={"file": ("sauvegarde.bastide", archive.content, "application/zip")},
    )

    assert restored.status_code == 200, restored.json()
    assert [row["amount_minor"] for row in listed(client, headers)] == [812_345]
