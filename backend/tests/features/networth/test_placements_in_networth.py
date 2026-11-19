"""Placements in net worth: today's assets, the composition, and the month-end series."""

from datetime import date

from fastapi.testclient import TestClient

from tests.api import register
from tests.features.networth.test_networth import add_snapshot, create_account, summary

PEA = {
    "name": "PEA Bourse",
    "institution": "Banque Exemple",
    "envelope": "pea",
    "opened_on": "2026-02-10",
    "initial_payments_minor": 300_000,
}


def create_placement(client: TestClient, headers: dict[str, str], **overrides: object) -> dict:
    response = client.post("/api/v1/investments", json={**PEA, **overrides}, headers=headers)
    assert response.status_code == 201, response.json()
    return dict(response.json())


def test_a_placement_counts_at_its_last_declared_value(client: TestClient) -> None:
    headers = register(client)
    create_account(client, headers, 100_000)
    pea = create_placement(client, headers)
    client.post(
        f"/api/v1/investments/{pea['id']}/valuations",
        json={"valued_on": "2026-04-30", "value_minor": 330_000},
        headers=headers,
    )

    body = summary(client, headers)

    assert body["assets"]["investments_minor"] == 330_000
    assert body["net_worth_minor"] == 100_000 + 330_000
    assert ("investment", "pea", 330_000) in [
        (e["group"], e["key"], e["amount_minor"]) for e in body["composition"]
    ]
    assert sum(e["share_bps"] for e in body["composition"]) == 10_000


def test_a_placement_without_a_value_counts_its_net_payments(client: TestClient) -> None:
    headers = register(client)
    create_placement(client, headers, envelope="life_insurance")

    assets = summary(client, headers)["assets"]

    assert assets["investments_minor"] == 300_000


def test_a_closed_placement_leaves_net_worth(client: TestClient) -> None:
    headers = register(client)
    pea = create_placement(client, headers)
    client.post(
        f"/api/v1/investments/{pea['id']}/close",
        json={"closed_on": "2026-04-02", "final_amount_minor": 310_000},
        headers=headers,
    )

    body = summary(client, headers)

    assert body["assets"]["investments_minor"] == 0
    assert body["composition"] == []


def test_the_series_adds_each_placement_from_its_opening_month(client: TestClient) -> None:
    headers = register(client)
    account = create_account(client, headers, 50_000)
    for month_end in (date(2026, 1, 31), date(2026, 2, 28), date(2026, 3, 31)):
        add_snapshot(client, account["id"], month_end, 50_000)
    pea = create_placement(client, headers)
    client.post(
        f"/api/v1/investments/{pea['id']}/valuations",
        json={"valued_on": "2026-03-15", "value_minor": 315_000},
        headers=headers,
    )

    series = summary(client, headers)["series"]

    assert [(p["month"], p["net_worth_minor"]) for p in series] == [
        ("2026-01", 50_000),
        ("2026-02", 50_000 + 300_000),
        ("2026-03", 50_000 + 315_000),
    ]
