"""Tests for the date a goal was reached: derived from its ledger, never stored."""

from datetime import date

from fastapi.testclient import TestClient

from app.features.goals.service import reached_on
from tests.api import register
from tests.features.goals.test_goals import allocate, create_goal, list_goals


def test_an_empty_ledger_was_never_reached() -> None:
    assert reached_on(1_000, []) is None


def test_the_line_that_crosses_the_target_dates_it() -> None:
    ledger = [(date(2026, 1, 5), 600), (date(2026, 3, 9), 500), (date(2026, 4, 2), 100)]

    assert reached_on(1_000, ledger) == date(2026, 3, 9)


def test_a_withdrawal_under_the_target_forgets_the_earlier_crossing() -> None:
    ledger = [
        (date(2026, 1, 5), 1_000),
        (date(2026, 2, 1), -300),
        (date(2026, 5, 20), 400),
    ]

    assert reached_on(1_000, ledger) == date(2026, 5, 20)


def test_a_goal_still_under_its_target_has_no_date() -> None:
    assert reached_on(1_000, [(date(2026, 1, 5), 1_000), (date(2026, 2, 1), -1)]) is None


def test_the_api_reports_the_reached_date(client: TestClient) -> None:
    headers = register(client)
    goal = create_goal(client, headers, target_minor=100_000)
    other = create_goal(client, headers, name="Voyage", target_minor=500_000)
    allocate(client, headers, goal["id"], 60_000, allocated_on="2026-02-01")
    allocate(client, headers, goal["id"], 40_000, allocated_on="2026-04-12")
    allocate(client, headers, other["id"], 10_000, allocated_on="2026-04-12")

    listed = {row["id"]: row for row in list_goals(client, headers)}

    assert listed[goal["id"]]["status"] == "reached"
    assert listed[goal["id"]]["reached_on"] == "2026-04-12"
    assert listed[other["id"]]["reached_on"] is None
