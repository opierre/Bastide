"""Tests for the summary's totals and debt ratio: income source, median, and the HCSF reading.

What is at stake is that the ratio is a reading the user can check — its denominator is named,
a bonus month cannot inflate it, a thin ledger yields no ratio at all — and that the HCSF
reference never refuses a write.
"""

from datetime import date
from pathlib import Path
from typing import cast

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker

from app.features.accounts.models import Account
from app.features.categories.models import Category
from app.features.imports.models import ImportBatch
from app.features.mortgages.router import get_today
from app.features.settings.models import UserSettings
from app.features.transactions.models import Transaction
from tests.api import register

TODAY = date(2026, 5, 15)

LOAN_PAYLOAD = {
    "label": "Appartement Lyon 3e",
    "lender": "BNP Paribas",
    "kind": "mortgage",
    "repayment_type": "constant_payment",
    "principal_minor": 24_000_000,
    "annual_rate_bps": 345,
    "insurance_monthly_minor": 2_880,
    "term_months": 300,
    "first_payment_date": "2023-09-01",
    "upfront_fees_minor": 145_000,
}

WORKS_PAYLOAD = {
    **LOAN_PAYLOAD,
    "label": "Travaux cuisine",
    "lender": "Crédit Agricole",
    "kind": "works",
    "principal_minor": 1_500_000,
    "annual_rate_bps": 490,
    "insurance_monthly_minor": 0,
    "term_months": 60,
    "first_payment_date": "2025-03-01",
    "upfront_fees_minor": 0,
}

#: The last twelve complete months before TODAY.
COMPLETE_MONTHS = [date(2025, month, 5) for month in range(5, 13)] + [
    date(2026, month, 5) for month in range(1, 5)
]


@pytest.fixture(autouse=True)
def pinned_today(client: TestClient) -> None:
    cast(FastAPI, client.app).dependency_overrides[get_today] = lambda: TODAY


def db(tmp_path: Path) -> Session:
    engine = create_engine(f"sqlite:///{tmp_path / 'test.db'}")
    return sessionmaker(bind=engine)()


def user_id_of(client: TestClient, headers: dict[str, str]) -> str:
    return str(client.get("/api/v1/auth/me", headers=headers).json()["user"]["id"])


def create_loan(client: TestClient, headers: dict[str, str], **overrides: object) -> dict:
    response = client.post("/api/v1/mortgages", json={**LOAN_PAYLOAD, **overrides}, headers=headers)
    assert response.status_code == 201, response.json()
    return dict(response.json())


def summary(client: TestClient, headers: dict[str, str]) -> dict:
    response = client.get("/api/v1/mortgages/summary", headers=headers)
    assert response.status_code == 200, response.json()
    return dict(response.json())


def declare_income(tmp_path: Path, user_id: str, amount_minor: int) -> None:
    with db(tmp_path) as session:
        session.add(UserSettings(user_id=user_id, declared_monthly_income_minor=amount_minor))
        session.commit()


def create_account(client: TestClient, headers: dict[str, str]) -> str:
    response = client.post(
        "/api/v1/accounts",
        json={
            "name": "Compte courant",
            "type": "checking",
            "institution": "BNP Paribas",
            "opening_balance_minor": 100_000,
        },
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return str(response.json()["id"])


def category_of_kind(tmp_path: Path, kind: str) -> str:
    with db(tmp_path) as session:
        category_id = session.scalar(
            select(Category.id).where(Category.is_system.is_(True), Category.kind == kind).limit(1)
        )
    assert category_id is not None, kind
    return category_id


def book(
    tmp_path: Path, account_id: str, booked_on: date, amount_minor: int, category_id: str | None
) -> None:
    """Insert one ledger row straight into the client's database (no import pipeline here)."""
    with db(tmp_path) as session:
        account = session.get(Account, account_id)
        assert account is not None
        unique = f"{account_id}-{booked_on.isoformat()}-{amount_minor}-{category_id}"
        batch = ImportBatch(
            user_id=account.user_id,
            account_id=account_id,
            source_format="ofx",
            file_name="test.ofx",
            file_hash=f"hash-{unique}",
            period_start=booked_on,
            period_end=booked_on,
            transaction_count=1,
            new_count=1,
            duplicate_count=0,
            status="success",
        )
        session.add(batch)
        session.flush()
        session.add(
            Transaction(
                account_id=account_id,
                import_batch_id=batch.id,
                booked_date=booked_on,
                amount_minor=amount_minor,
                currency="EUR",
                description_raw="VIREMENT",
                description_clean="VIREMENT",
                category_id=category_id,
                categorization_source="user",
                needs_review=False,
                dedup_hash=f"dedup-{unique}",
            )
        )
        session.commit()


def book_salaries(
    tmp_path: Path, account_id: str, category_id: str, amounts: list[int], months: list[date]
) -> None:
    for booked_on, amount in zip(months, amounts, strict=True):
        book(tmp_path, account_id, booked_on, amount, category_id)


def expected_ratio(charge: int, income: int) -> int:
    return (2 * charge * 10_000 + income) // (2 * income)


# --- income source ---------------------------------------------------------------------------


def test_the_declared_income_wins_over_the_ledger(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    account_id = create_account(client, headers)
    salary = category_of_kind(tmp_path, "income")
    book_salaries(tmp_path, account_id, salary, [285_000] * 12, COMPLETE_MONTHS)
    declare_income(tmp_path, user_id_of(client, headers), 460_000)
    loan = create_loan(client, headers)

    body = summary(client, headers)

    assert body["income_source"] == "declared"
    assert body["monthly_income_minor"] == 460_000
    assert body["debt_ratio_bps"] == expected_ratio(loan["total_instalment_minor"], 460_000)


def test_the_ledger_median_ignores_a_bonus_month(client: TestClient, tmp_path: Path) -> None:
    """Eleven months at 2 850 € and a December doubled by the 13th month: the mean would be
    3 087,50 €, the median stays 2 850 €."""
    headers = register(client)
    account_id = create_account(client, headers)
    salary = category_of_kind(tmp_path, "income")
    amounts = [285_000] * 12
    amounts[COMPLETE_MONTHS.index(date(2025, 12, 5))] = 570_000
    book_salaries(tmp_path, account_id, salary, amounts, COMPLETE_MONTHS)
    loan = create_loan(client, headers)

    body = summary(client, headers)

    assert sum(amounts) // 12 == 308_750
    assert body["income_source"] == "ledger"
    assert body["monthly_income_minor"] == 285_000
    assert body["debt_ratio_bps"] == expected_ratio(loan["total_instalment_minor"], 285_000)


def test_the_median_sums_each_month_before_ranking(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    account_id = create_account(client, headers)
    salary = category_of_kind(tmp_path, "income")
    months = COMPLETE_MONTHS[-3:]
    book_salaries(tmp_path, account_id, salary, [100_000, 200_000, 900_000], months)
    # A second salary in the first month lifts that month to 250 000, now the middle value.
    book(tmp_path, account_id, date(2026, 2, 20), 150_000, salary)

    assert summary(client, headers)["monthly_income_minor"] == 250_000


def test_an_even_count_takes_the_mean_of_the_middle_two(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    account_id = create_account(client, headers)
    salary = category_of_kind(tmp_path, "income")
    book_salaries(
        tmp_path, account_id, salary, [100_000, 200_001, 300_000, 900_000], COMPLETE_MONTHS[-4:]
    )

    assert summary(client, headers)["monthly_income_minor"] == 250_001


def test_only_complete_months_of_income_on_live_accounts_count(
    client: TestClient, tmp_path: Path
) -> None:
    headers = register(client)
    account_id = create_account(client, headers)
    archived_account = create_account(client, headers)
    salary = category_of_kind(tmp_path, "income")
    book_salaries(tmp_path, account_id, salary, [300_000] * 3, COMPLETE_MONTHS[-3:])
    noise = [
        (account_id, TODAY, 9_000_000, salary),  # the current, incomplete month
        (account_id, date(2025, 4, 30), 9_000_000, salary),  # thirteen months back
        (account_id, date(2026, 4, 10), 9_000_000, category_of_kind(tmp_path, "transfer")),
        (account_id, date(2026, 4, 11), -50_000, category_of_kind(tmp_path, "expense")),
        (account_id, date(2026, 4, 12), 9_000_000, None),  # uncategorised
        (archived_account, date(2026, 4, 13), 9_000_000, salary),
    ]
    for row in noise:
        book(tmp_path, *row)
    with db(tmp_path) as session:
        account = session.get(Account, archived_account)
        assert account is not None
        account.archived = True
        session.commit()

    body = summary(client, headers)

    assert (body["income_source"], body["monthly_income_minor"]) == ("ledger", 300_000)


def test_under_three_months_of_income_the_ratio_is_unknown(
    client: TestClient, tmp_path: Path
) -> None:
    headers = register(client)
    account_id = create_account(client, headers)
    salary = category_of_kind(tmp_path, "income")
    book_salaries(tmp_path, account_id, salary, [285_000] * 2, COMPLETE_MONTHS[-2:])
    create_loan(client, headers)

    body = summary(client, headers)

    assert body["income_source"] == "unknown"
    assert body["monthly_income_minor"] is None
    assert body["debt_ratio_bps"] is None
    assert body["over_limit"] is False
    assert body["hcsf_limit_bps"] == 3500


def test_a_user_without_any_history_has_no_ratio(client: TestClient) -> None:
    headers = register(client)

    body = summary(client, headers)

    assert body["income_source"] == "unknown"
    assert body["debt_ratio_bps"] is None
    assert body["active_count"] == 0
    assert body["monthly_charge_minor"] == 0
    assert body["next_payment_on"] is None
    assert body["by_lender"] == []
    assert body["outstanding_series"] == []
    assert body["currency"] == "EUR"


# --- totals ----------------------------------------------------------------------------------


def test_totals_sum_the_active_loans(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    declare_income(tmp_path, user_id_of(client, headers), 460_000)
    home = create_loan(client, headers)
    works = create_loan(client, headers, **WORKS_PAYLOAD)

    body = summary(client, headers)

    loans = (home, works)
    charge = sum(loan["total_instalment_minor"] for loan in loans)
    outstanding = sum(loan["outstanding_principal_minor"] for loan in loans)
    assert body["active_count"] == 2
    assert body["monthly_charge_minor"] == charge
    assert body["total_outstanding_minor"] == outstanding
    assert body["total_principal_minor"] == 25_500_000
    assert body["repaid_principal_minor"] == 25_500_000 - outstanding
    assert body["repaid_pct_bps"] == expected_ratio(25_500_000 - outstanding, 25_500_000)
    assert body["next_payment_on"] == "2026-06-01"
    assert body["next_payment_count"] == 2
    assert body["by_lender"] == [
        {"lender": "BNP Paribas", "monthly_charge_minor": home["total_instalment_minor"]},
        {"lender": "Crédit Agricole", "monthly_charge_minor": works["total_instalment_minor"]},
    ]
    assert sum(item["monthly_charge_minor"] for item in body["by_lender"]) == charge
    assert body["debt_ratio_bps"] == expected_ratio(charge, 460_000)


def test_by_lender_merges_loans_from_the_same_lender(client: TestClient) -> None:
    headers = register(client)
    home = create_loan(client, headers)
    works = create_loan(client, headers, **{**WORKS_PAYLOAD, "lender": "BNP Paribas"})

    body = summary(client, headers)

    assert body["by_lender"] == [
        {
            "lender": "BNP Paribas",
            "monthly_charge_minor": home["total_instalment_minor"]
            + works["total_instalment_minor"],
        }
    ]


def test_next_payment_count_only_counts_the_soonest_date(client: TestClient) -> None:
    headers = register(client)
    create_loan(client, headers)
    create_loan(client, headers, **{**WORKS_PAYLOAD, "first_payment_date": "2025-03-20"})

    body = summary(client, headers)

    assert (body["next_payment_on"], body["next_payment_count"]) == ("2026-05-20", 1)


def test_archived_and_repaid_loans_are_excluded(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    declare_income(tmp_path, user_id_of(client, headers), 460_000)
    home = create_loan(client, headers)
    archived = create_loan(client, headers, **WORKS_PAYLOAD)
    repaid = create_loan(client, headers, **{**WORKS_PAYLOAD, "lender": "LCL"})
    client.delete(f"/api/v1/mortgages/{archived['id']}", headers=headers)
    client.patch(f"/api/v1/mortgages/{repaid['id']}", json={"status": "repaid"}, headers=headers)

    body = summary(client, headers)

    assert body["active_count"] == 1
    assert body["monthly_charge_minor"] == home["total_instalment_minor"]
    assert body["total_outstanding_minor"] == home["outstanding_principal_minor"]
    assert body["total_principal_minor"] == 24_000_000
    assert [item["lender"] for item in body["by_lender"]] == ["BNP Paribas"]
    assert [end["mortgage_id"] for end in body["loan_ends"]] == [home["id"]]
    assert body["debt_ratio_bps"] == expected_ratio(home["total_instalment_minor"], 460_000)


# --- the HCSF reading ------------------------------------------------------------------------


def test_over_limit_never_blocks_a_write(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    home = create_loan(client, headers)
    # An income that puts the one loan at a 60 % ratio.
    income = home["total_instalment_minor"] * 10_000 // 6_000
    declare_income(tmp_path, user_id_of(client, headers), income)
    assert abs(summary(client, headers)["debt_ratio_bps"] - 6_000) <= 1

    created = client.post("/api/v1/mortgages", json=WORKS_PAYLOAD, headers=headers)
    patched = client.patch(
        f"/api/v1/mortgages/{home['id']}", json={"annual_rate_bps": 500}, headers=headers
    )

    assert created.status_code == 201
    assert patched.status_code == 200
    body = summary(client, headers)
    assert body["over_limit"] is True
    assert body["debt_ratio_bps"] > body["hcsf_limit_bps"] == 3500


def test_a_ratio_at_the_limit_is_not_over_it(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    home = create_loan(client, headers)
    declare_income(tmp_path, user_id_of(client, headers), home["total_instalment_minor"] * 2)

    body = summary(client, headers)

    assert body["debt_ratio_bps"] == 5_000
    assert body["over_limit"] is True


def test_the_summary_is_user_scoped(client: TestClient) -> None:
    owner = register(client)
    other = register(client, email="bruno@example.com")
    create_loan(client, owner)

    assert summary(client, other)["active_count"] == 0
    assert client.get("/api/v1/mortgages/summary").status_code == 401
