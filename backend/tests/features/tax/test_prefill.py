"""Tests for the ledger prefill: what it sums, what it admits about its coverage, what it never
does.

What is at stake is that a suggestion stays a suggestion. The endpoint reads the ledger and
returns figures the user has not accepted yet, so it must write nothing at all, and it must say
how much of the year it actually saw — a figure derived from four months of statements is not an
annual income, and confidence is where the endpoint says so.
"""

from datetime import date
from pathlib import Path
from typing import cast

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session, sessionmaker

from app.features.accounts.models import Account
from app.features.categories.models import Category
from app.features.imports.models import ImportBatch
from app.features.tax.models import TaxParameter, TaxProfile
from app.features.tax.router import get_today
from app.features.tax.seed import SYSTEM_TAX_SEED
from app.features.tax.service import PREFILL_CATEGORY_KEYS
from app.features.transactions.models import Transaction

TODAY = date(2026, 5, 15)

#: The year the ledger is seeded for: complete, and old enough to have a full twelve months.
YEAR = SYSTEM_TAX_SEED.tax_year

SALARY_KEY = PREFILL_CATEGORY_KEYS["salaries_minor"]
PENSION_KEY = PREFILL_CATEGORY_KEYS["pensions_minor"]
DIVIDEND_KEY = PREFILL_CATEGORY_KEYS["dividends_minor"]
INTEREST_KEY = PREFILL_CATEGORY_KEYS["interest_minor"]

#: The twelve months of `YEAR`, and the first four of it.
FULL_YEAR = [date(YEAR, month, 5) for month in range(1, 13)]
FOUR_MONTHS = FULL_YEAR[:4]


@pytest.fixture(autouse=True)
def pinned_today(client: TestClient) -> None:
    cast(FastAPI, client.app).dependency_overrides[get_today] = lambda: TODAY


@pytest.fixture(autouse=True)
def seeded_parameters(client: TestClient, tmp_path: Path) -> None:
    """The client database is built from metadata, so the seed migration's rows are added here."""
    with db(tmp_path) as session:
        for key, parameter in SYSTEM_TAX_SEED.parameters.items():
            session.add(
                TaxParameter(
                    user_id=None,
                    tax_year=YEAR,
                    key=key,
                    int_value=parameter.int_value,
                    unit=parameter.unit,
                )
            )
        session.commit()


def db(tmp_path: Path) -> Session:
    engine = create_engine(f"sqlite:///{tmp_path / 'test.db'}")
    return sessionmaker(bind=engine)()


def register(client: TestClient, email: str = "amelie@example.com") -> dict[str, str]:
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
    assert response.status_code == 201, response.json()
    return {"Authorization": f"Bearer {response.json()['token']}"}


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


def category_id(tmp_path: Path, key: str) -> str:
    """The system category holding this i18n key — `categories.name` for system rows."""
    with db(tmp_path) as session:
        found = session.scalar(
            select(Category.id).where(Category.is_system.is_(True), Category.name == key)
        )
    assert found is not None, key
    return found


def book(
    tmp_path: Path, account_id: str, booked_on: date, amount_minor: int, category: str | None
) -> None:
    """Insert one ledger row straight into the client's database (no import pipeline here)."""
    with db(tmp_path) as session:
        account = session.get(Account, account_id)
        assert account is not None
        unique = f"{account_id}-{booked_on.isoformat()}-{amount_minor}-{category}"
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
                category_id=category,
                categorization_source="user",
                needs_review=False,
                dedup_hash=f"dedup-{unique}",
            )
        )
        session.commit()


def book_months(
    tmp_path: Path,
    account_id: str,
    category: str,
    months: list[date],
    amounts: list[int],
) -> None:
    for booked_on, amount in zip(months, amounts, strict=True):
        book(tmp_path, account_id, booked_on, amount, category)


def prefill(client: TestClient, headers: dict[str, str], year: int = YEAR) -> dict:
    response = client.get("/api/v1/tax/prefill", params={"year": year}, headers=headers)
    assert response.status_code == 200, response.json()
    return dict(response.json())


def profile_snapshot(tmp_path: Path) -> list[tuple]:
    """Every stored profile column that a write could possibly disturb."""
    with db(tmp_path) as session:
        return [
            (
                profile.id,
                profile.tax_year,
                profile.household,
                profile.dependents_count,
                profile.single_parent,
                profile.salaries_minor,
                profile.pensions_minor,
                profile.dividends_minor,
                profile.interest_minor,
                profile.capital_gains_minor,
                profile.pfu_opt_out,
                profile.deductions_minor,
                profile.credits_minor,
                profile.updated_at,
            )
            for profile in session.scalars(select(TaxProfile).order_by(TaxProfile.tax_year))
        ]


def profile_rows(tmp_path: Path) -> int:
    with db(tmp_path) as session:
        return int(session.scalar(select(func.count()).select_from(TaxProfile)) or 0)


def error_of(response) -> dict:  # noqa: ANN001 - httpx.Response, kept untyped like its siblings
    body = response.json()
    assert set(body) == {"error"}, body
    assert {"code", "message"} <= set(body["error"]), body
    return dict(body["error"])


# --- what it sums ----------------------------------------------------------------------------


def test_it_sums_each_category_into_its_own_field(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    account = create_account(client, headers)
    book_months(tmp_path, account, category_id(tmp_path, SALARY_KEY), FULL_YEAR, [285_000] * 12)
    book_months(tmp_path, account, category_id(tmp_path, PENSION_KEY), FULL_YEAR, [40_000] * 12)
    book_months(tmp_path, account, category_id(tmp_path, DIVIDEND_KEY), FULL_YEAR, [10_000] * 12)
    book_months(tmp_path, account, category_id(tmp_path, INTEREST_KEY), FOUR_MONTHS, [8_000] * 4)

    suggestion = prefill(client, headers)

    assert suggestion["salaries_minor"] == 3_420_000
    assert suggestion["pensions_minor"] == 480_000
    assert suggestion["dividends_minor"] == 120_000
    assert suggestion["interest_minor"] == 32_000


def test_the_source_is_always_the_ledger(client: TestClient) -> None:
    headers = register(client)

    assert prefill(client, headers)["source"] == "ledger"
    assert prefill(client, headers)["currency"] == "EUR"
    assert prefill(client, headers)["tax_year"] == YEAR


def test_months_of_another_year_are_left_out(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    account = create_account(client, headers)
    salary = category_id(tmp_path, SALARY_KEY)
    book_months(tmp_path, account, salary, FULL_YEAR, [285_000] * 12)
    book(tmp_path, account, date(YEAR + 1, 1, 5), 285_000, salary)
    book(tmp_path, account, date(YEAR - 1, 12, 5), 285_000, salary)

    assert prefill(client, headers)["salaries_minor"] == 3_420_000


def test_an_uncategorised_transaction_suggests_nothing(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    account = create_account(client, headers)
    book(tmp_path, account, FULL_YEAR[0], 285_000, None)

    suggestion = prefill(client, headers)

    assert suggestion["salaries_minor"] == 0
    assert suggestion["months_covered"] == 0


def test_several_transactions_in_one_month_are_one_month(
    client: TestClient, tmp_path: Path
) -> None:
    headers = register(client)
    account = create_account(client, headers)
    salary = category_id(tmp_path, SALARY_KEY)
    book(tmp_path, account, date(YEAR, 1, 5), 285_000, salary)
    book(tmp_path, account, date(YEAR, 1, 20), 15_000, salary)

    suggestion = prefill(client, headers)

    assert suggestion["salaries_minor"] == 300_000
    assert suggestion["months_covered"] == 1


def test_a_category_netting_out_negative_suggests_zero(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    account = create_account(client, headers)
    salary = category_id(tmp_path, SALARY_KEY)
    book(tmp_path, account, date(YEAR, 1, 5), 285_000, salary)
    book(tmp_path, account, date(YEAR, 2, 5), -300_000, salary)

    assert prefill(client, headers)["salaries_minor"] == 0


# --- coverage and confidence -----------------------------------------------------------------


def test_a_full_steady_year_is_high_confidence(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    account = create_account(client, headers)
    book_months(tmp_path, account, category_id(tmp_path, SALARY_KEY), FULL_YEAR, [285_000] * 12)

    suggestion = prefill(client, headers)

    assert suggestion["months_covered"] == 12
    assert suggestion["per_field_confidence"]["salaries_minor"] == "high"


def test_a_four_month_year_is_low_confidence(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    account = create_account(client, headers)
    book_months(tmp_path, account, category_id(tmp_path, SALARY_KEY), FOUR_MONTHS, [285_000] * 4)

    suggestion = prefill(client, headers)

    assert suggestion["months_covered"] == 4
    assert suggestion["per_field_confidence"]["salaries_minor"] == "low"


def test_a_full_but_uneven_year_is_medium_confidence(client: TestClient, tmp_path: Path) -> None:
    """A 13th-month bonus is twelve months of coverage whose total is not twelve typical ones."""
    headers = register(client)
    account = create_account(client, headers)
    amounts = [285_000] * 11 + [570_000]
    book_months(tmp_path, account, category_id(tmp_path, SALARY_KEY), FULL_YEAR, amounts)

    suggestion = prefill(client, headers)

    assert suggestion["months_covered"] == 12
    assert suggestion["per_field_confidence"]["salaries_minor"] == "medium"


def test_a_full_year_inside_the_band_stays_high(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    account = create_account(client, headers)
    amounts = [285_000] * 11 + [330_000]  # +15,8 %, inside the 20 % band.
    book_months(tmp_path, account, category_id(tmp_path, SALARY_KEY), FULL_YEAR, amounts)

    assert prefill(client, headers)["per_field_confidence"]["salaries_minor"] == "high"


def test_confidence_is_judged_per_field(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    account = create_account(client, headers)
    book_months(tmp_path, account, category_id(tmp_path, SALARY_KEY), FULL_YEAR, [285_000] * 12)
    book_months(tmp_path, account, category_id(tmp_path, INTEREST_KEY), FOUR_MONTHS, [8_000] * 4)

    confidence = prefill(client, headers)["per_field_confidence"]

    assert confidence["salaries_minor"] == "high"
    assert confidence["interest_minor"] == "low"


def test_an_empty_year_returns_zeros_and_no_coverage(client: TestClient) -> None:
    headers = register(client)

    suggestion = prefill(client, headers)

    assert suggestion["months_covered"] == 0
    assert [
        suggestion[field]
        for field in ("salaries_minor", "pensions_minor", "dividends_minor", "interest_minor")
    ] == [0, 0, 0, 0]
    assert set(suggestion["per_field_confidence"].values()) == {"low"}


# --- it never writes -------------------------------------------------------------------------


def test_the_prefill_creates_no_profile(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    account = create_account(client, headers)
    book_months(tmp_path, account, category_id(tmp_path, SALARY_KEY), FULL_YEAR, [285_000] * 12)

    prefill(client, headers)

    assert profile_rows(tmp_path) == 0


def test_the_profile_is_unchanged_by_the_prefill(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    account = create_account(client, headers)
    book_months(tmp_path, account, category_id(tmp_path, SALARY_KEY), FULL_YEAR, [285_000] * 12)
    client.patch(f"/api/v1/tax/profiles/{YEAR}", json={"salaries_minor": 1_000}, headers=headers)
    before = profile_snapshot(tmp_path)

    suggestion = prefill(client, headers)

    assert suggestion["salaries_minor"] == 3_420_000  # The ledger offers a different figure…
    assert profile_snapshot(tmp_path) == before  # …and the stored row keeps the user's.


# --- scoping and the year range ---------------------------------------------------------------


def test_another_users_ledger_is_never_read(client: TestClient, tmp_path: Path) -> None:
    amelie = register(client)
    account = create_account(client, amelie)
    book_months(tmp_path, account, category_id(tmp_path, SALARY_KEY), FULL_YEAR, [285_000] * 12)
    bruno = register(client, "bruno@example.com")

    suggestion = prefill(client, bruno)

    assert suggestion["salaries_minor"] == 0
    assert suggestion["months_covered"] == 0


def test_an_archived_account_leaves_the_suggestion(client: TestClient, tmp_path: Path) -> None:
    headers = register(client)
    account = create_account(client, headers)
    book_months(tmp_path, account, category_id(tmp_path, SALARY_KEY), FULL_YEAR, [285_000] * 12)

    assert client.delete(f"/api/v1/accounts/{account}", headers=headers).status_code == 204

    assert prefill(client, headers)["salaries_minor"] == 0


def test_a_future_year_is_refused(client: TestClient) -> None:
    headers = register(client)

    response = client.get("/api/v1/tax/prefill", params={"year": TODAY.year + 1}, headers=headers)

    assert response.status_code == 422, response.json()
    assert error_of(response)["code"] == "TAX_YEAR_OUT_OF_RANGE"


def test_the_prefill_requires_authentication(client: TestClient) -> None:
    assert client.get("/api/v1/tax/prefill", params={"year": YEAR}).status_code == 401
