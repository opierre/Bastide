"""Tests for the allocation ledger: the signed sum, what it does to a goal's status, and the
line it draws around itself — allocating money is bookkeeping, never a transaction.
"""

from datetime import date
from typing import Any

from fastapi.testclient import TestClient
from sqlalchemy import event
from sqlalchemy.orm import Session

from app.features.goals.models import Goal, GoalAllocation
from app.features.goals.repository import GoalRepository
from tests.factories import make_user
from tests.features.goals.test_goals import (
    allocate,
    create_goal,
    list_goals,
    read_goal,
    register,
)

ACCOUNT_PAYLOAD = {
    "name": "Livret A",
    "type": "savings",
    "institution": "BNP Paribas",
    "opening_balance_minor": 2_210_000,
}


def list_allocations(client: TestClient, headers: dict[str, str], goal_id: str) -> list[dict]:
    response = client.get(f"/api/v1/goals/{goal_id}/allocations", headers=headers)
    assert response.status_code == 200, response.json()
    return list(response.json())


# --- the signed sum -------------------------------------------------------------------------


def test_progress_is_the_signed_sum_of_the_allocations(client: TestClient) -> None:
    headers = register(client)
    goal_id = create_goal(client, headers, target_minor=1_000_000)["id"]

    allocate(client, headers, goal_id, 30_000, "2026-03-01", "Virement mensuel")
    allocate(client, headers, goal_id, -15_000, "2026-03-12", "Réparation voiture")
    allocate(client, headers, goal_id, 30_000, "2026-04-01", "Virement mensuel")

    goal = read_goal(client, headers, goal_id)
    assert goal["progress_minor"] == 45_000
    assert goal["progress_pct"] == 0.045


def test_the_history_reads_newest_first(client: TestClient) -> None:
    headers = register(client)
    goal_id = create_goal(client, headers)["id"]
    allocate(client, headers, goal_id, 30_000, "2026-03-01")
    allocate(client, headers, goal_id, -15_000, "2026-03-12")
    allocate(client, headers, goal_id, 30_000, "2026-04-01")

    assert [line["allocated_on"] for line in list_allocations(client, headers, goal_id)] == [
        "2026-04-01",
        "2026-03-12",
        "2026-03-01",
    ]


def test_an_allocation_carries_no_account(client: TestClient) -> None:
    headers = register(client)
    goal_id = create_goal(client, headers)["id"]

    response = client.post(
        f"/api/v1/goals/{goal_id}/allocations",
        json={"amount_minor": 30_000, "allocated_on": "2026-05-01", "account_id": "somewhere"},
        headers=headers,
    )

    assert response.status_code == 422


def test_there_is_no_way_to_edit_an_allocation(client: TestClient) -> None:
    """An honest ledger is append-only: a real correction is an offsetting line, and DELETE
    exists only to undo a mistyped one."""
    headers = register(client)
    goal_id = create_goal(client, headers)["id"]
    allocation_id = allocate(client, headers, goal_id, 30_000)["id"]

    response = client.patch(
        f"/api/v1/goals/{goal_id}/allocations/{allocation_id}",
        json={"amount_minor": 1},
        headers=headers,
    )

    assert response.status_code == 405


# --- status ---------------------------------------------------------------------------------


def test_a_negative_allocation_takes_a_goal_back_out_of_reached(client: TestClient) -> None:
    headers = register(client)
    goal_id = create_goal(client, headers, target_minor=400_000)["id"]
    allocate(client, headers, goal_id, 400_000)
    assert read_goal(client, headers, goal_id)["status"] == "reached"

    allocate(client, headers, goal_id, -1)

    goal = read_goal(client, headers, goal_id)
    assert goal["status"] == "active"
    assert goal["progress_minor"] == 399_999


def test_deleting_an_allocation_recomputes_the_status(client: TestClient) -> None:
    headers = register(client)
    goal_id = create_goal(client, headers, target_minor=400_000)["id"]
    allocate(client, headers, goal_id, 300_000)
    mistyped = allocate(client, headers, goal_id, 100_000)["id"]
    assert read_goal(client, headers, goal_id)["status"] == "reached"

    response = client.delete(f"/api/v1/goals/{goal_id}/allocations/{mistyped}", headers=headers)

    assert response.status_code == 204
    goal = read_goal(client, headers, goal_id)
    assert goal["status"] == "active"
    assert goal["progress_minor"] == 300_000
    assert len(list_allocations(client, headers, goal_id)) == 1


def test_deleting_an_allocation_can_bring_a_goal_back_to_reached(client: TestClient) -> None:
    headers = register(client)
    goal_id = create_goal(client, headers, target_minor=400_000)["id"]
    allocate(client, headers, goal_id, 400_000)
    withdrawal = allocate(client, headers, goal_id, -50_000)["id"]
    assert read_goal(client, headers, goal_id)["status"] == "active"

    client.delete(f"/api/v1/goals/{goal_id}/allocations/{withdrawal}", headers=headers)

    assert read_goal(client, headers, goal_id)["status"] == "reached"


# --- over-allocation ------------------------------------------------------------------------


def test_over_allocating_is_accepted_and_reported_unclamped(client: TestClient) -> None:
    """Over-allocation is a warning the UI draws, never an error the API raises: the backend
    has no basis for deciding which money is savings."""
    headers = register(client)
    client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers)
    goal_id = create_goal(client, headers, target_minor=400_000)["id"]

    allocate(client, headers, goal_id, 600_000)

    goal = read_goal(client, headers, goal_id)
    assert goal["progress_minor"] == 600_000
    assert goal["progress_pct"] == 1.5
    assert goal["status"] == "reached"


def test_allocations_across_goals_may_exceed_the_savings_balance(client: TestClient) -> None:
    headers = register(client)
    client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers)
    first = create_goal(client, headers, name="Fonds d'urgence", target_minor=2_000_000)["id"]
    second = create_goal(client, headers, name="Voyage Japon", target_minor=2_000_000)["id"]

    allocate(client, headers, first, 1_500_000)
    allocate(client, headers, second, 1_500_000)

    assert sum(goal["progress_minor"] for goal in list_goals(client, headers)) == 3_000_000


# --- the line around the feature ------------------------------------------------------------


def test_allocating_writes_no_transaction_and_moves_no_balance(client: TestClient) -> None:
    headers = register(client)
    account = client.post("/api/v1/accounts", json=ACCOUNT_PAYLOAD, headers=headers).json()
    goal_id = create_goal(client, headers)["id"]

    allocate(client, headers, goal_id, 30_000)
    allocate(client, headers, goal_id, -15_000)

    assert client.get("/api/v1/transactions", headers=headers).json()["items"] == []
    unchanged = client.get(f"/api/v1/accounts/{account['id']}", headers=headers).json()
    assert unchanged["balance_minor"] == ACCOUNT_PAYLOAD["opening_balance_minor"]


# --- user scoping ---------------------------------------------------------------------------


def test_another_users_goal_takes_no_allocations(client: TestClient) -> None:
    owner = register(client)
    other = register(client, email="bruno@example.com")
    goal_id = create_goal(client, owner)["id"]
    allocation_id = allocate(client, owner, goal_id, 30_000)["id"]

    for method, url, payload in (
        ("GET", f"/api/v1/goals/{goal_id}/allocations", None),
        (
            "POST",
            f"/api/v1/goals/{goal_id}/allocations",
            {"amount_minor": 1, "allocated_on": "2026-05-01"},
        ),
        ("DELETE", f"/api/v1/goals/{goal_id}/allocations/{allocation_id}", None),
    ):
        response = client.request(method, url, json=payload, headers=other)
        assert response.status_code == 404, url
        assert response.json()["error"]["code"] == "GOAL_NOT_FOUND"


def test_an_allocation_of_another_goal_is_not_found(client: TestClient) -> None:
    headers = register(client)
    goal_id = create_goal(client, headers, name="Fonds d'urgence")["id"]
    other_goal_id = create_goal(client, headers, name="Voyage Japon")["id"]
    allocation_id = allocate(client, headers, other_goal_id, 30_000)["id"]

    response = client.delete(
        f"/api/v1/goals/{goal_id}/allocations/{allocation_id}", headers=headers
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "GOAL_ALLOCATION_NOT_FOUND"


# --- how progress is computed ---------------------------------------------------------------


def test_progress_comes_from_one_aggregate_not_from_loading_the_ledger(
    db_session: Session,
) -> None:
    """The panel draws every goal at once, so summing in Python would mean reading the whole
    allocation history to render a handful of progress bars."""
    # Read before the commit expires it, so the listener below sees only the list query.
    user_id = make_user(db_session).id
    goal = Goal(
        user_id=user_id,
        name="Fonds d'urgence",
        target_minor=1_000_000,
        currency="EUR",
        icon="shield",
        color="iris",
        status="active",
    )
    db_session.add(goal)
    db_session.flush()
    for index in range(20):
        db_session.add(
            GoalAllocation(
                goal_id=goal.id, amount_minor=30_000, allocated_on=date(2026, 5, 1 + index % 28)
            )
        )
    db_session.commit()

    statements: list[str] = []

    def record(
        conn: Any, cursor: Any, statement: str, parameters: Any, context: Any, many: bool
    ) -> None:
        statements.append(statement)

    event.listen(db_session.bind, "before_cursor_execute", record)
    try:
        listed = GoalRepository(db_session).list_for_user(user_id, ("active",))
    finally:
        event.remove(db_session.bind, "before_cursor_execute", record)

    assert listed == [(goal, 600_000)]
    assert len(statements) == 1
    assert "sum(" in statements[0].lower()
