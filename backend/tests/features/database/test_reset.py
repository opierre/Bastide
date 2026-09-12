"""Tests for the danger zone's database reset (`docs/design/09-settings.md` §Zone de danger)."""

from datetime import date
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker

from app.features.accounts.models import Account
from app.features.auth.models import User
from app.features.categories.models import Category
from app.features.categorization.models import CategorizationRun
from app.features.goals.models import Goal, GoalAllocation
from app.features.imports.models import ImportBatch
from app.features.mortgages.models import Mortgage, MortgageSimulation
from app.features.properties.models import Property
from app.features.recurring.models import RecurringSeries
from app.features.rules.models import CategorizationRule
from app.features.settings.models import UserSettings
from app.features.tax.models import TaxBracket, TaxParameter, TaxProfile
from app.features.transactions.models import Transaction


def _register(client: TestClient, email: str) -> dict[str, str]:
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


def _session(tmp_path: Path) -> Session:
    """A session on the `client` fixture's temp database."""
    engine = create_engine(f"sqlite:///{tmp_path / 'test.db'}")
    return sessionmaker(bind=engine)()


def _seed(db: Session, email: str) -> dict[str, str]:
    """Give the user one of everything the reset counts; returns the ids the tests assert on."""
    user = db.scalars(select(User).where(User.email == email)).one()
    system = db.scalars(select(Category).where(Category.user_id.is_(None))).first()
    assert system is not None
    category = Category(
        user_id=user.id,
        parent_id=system.id,
        name="Vélo",
        kind="expense",
        icon="bike",
        color="#4FD1E8",
    )
    account = Account(
        user_id=user.id,
        name="Compte courant",
        type="checking",
        institution="BNP",
        currency="EUR",
        opening_balance_minor=100_000,
        cached_balance_minor=95_766,
    )
    db.add_all([category, account])
    db.flush()
    batch = ImportBatch(
        user_id=user.id,
        account_id=account.id,
        source_format="ofx",
        file_name="releve.ofx",
        file_hash="a" * 64,
        period_start=date(2026, 8, 1),
        period_end=date(2026, 8, 31),
        transaction_count=1,
        new_count=1,
        duplicate_count=0,
        status="completed",
    )
    db.add(batch)
    db.flush()
    transaction = Transaction(
        account_id=account.id,
        import_batch_id=batch.id,
        booked_date=date(2026, 8, 14),
        amount_minor=-4_234,
        currency="EUR",
        description_raw="CB DECATHLON",
        description_clean="Decathlon",
        category_id=category.id,
        categorization_source="user",
        needs_review=False,
        dedup_hash="b" * 64,
    )
    rule = CategorizationRule(
        user_id=user.id,
        priority=1,
        match_field="description",
        match_type="contains",
        pattern="DECATHLON",
        category_id=category.id,
    )
    goal = Goal(
        user_id=user.id,
        name="Vacances",
        target_minor=150_000,
        currency="EUR",
        icon="sun",
        color="#4FD1E8",
        status="active",
    )
    series = RecurringSeries(
        user_id=user.id,
        account_id=account.id,
        merchant_key="netflix",
        label="Netflix",
        category_id=category.id,
        cadence="monthly",
        median_interval_days=30,
        expected_amount_minor=-1_399,
        currency="EUR",
        first_seen_date=date(2026, 1, 14),
        last_seen_date=date(2026, 8, 14),
        next_expected_date=date(2026, 9, 14),
        occurrence_count=8,
        status="active",
    )
    db.add_all([transaction, rule, goal, series])
    db.flush()
    db.add(GoalAllocation(goal_id=goal.id, amount_minor=20_000, allocated_on=date(2026, 8, 20)))
    home = Property(
        user_id=user.id,
        label="Résidence principale",
        kind="primary_residence",
        market_value_minor=32_000_000,
        valued_on=date(2026, 6, 1),
    )
    db.add(home)
    db.flush()
    loan = Mortgage(
        user_id=user.id,
        label="Résidence principale",
        lender="Crédit Agricole",
        property_id=home.id,
        kind="mortgage",
        repayment_type="constant_payment",
        principal_minor=25_000_000,
        annual_rate_bps=345,
        term_months=300,
        first_payment_date=date(2024, 3, 5),
        status="active",
    )
    db.add_all(
        [
            loan,
            MortgageSimulation(
                user_id=user.id,
                label="T3 Nantes",
                property_price_minor=28_000_000,
                down_payment_minor=4_000_000,
                principal_minor=26_000_000,
                annual_rate_bps=330,
                insurance_monthly_minor=3_800,
                term_months=240,
                upfront_fees_minor=150_000,
            ),
            TaxProfile(
                user_id=user.id, tax_year=2025, household="single", salaries_minor=4_200_000
            ),
            TaxBracket(
                user_id=user.id,
                tax_year=2025,
                kind="ir",
                ordinal=0,
                lower_bound_minor=0,
                rate_bps=0,
            ),
            TaxParameter(
                user_id=user.id,
                tax_year=2025,
                key="pfu_income_tax_bps",
                int_value=1300,
                unit="bps",
            ),
        ]
    )
    db.commit()
    return {
        "user": user.id,
        "account": account.id,
        "transaction": transaction.id,
        "goal": goal.id,
        "mortgage": loan.id,
    }


def test_summary_counts_the_callers_own_rows(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client, "amelie@example.com")
    with _session(tmp_path) as db:
        _seed(db, "amelie@example.com")

    response = client.get("/api/v1/database/summary", headers=headers)

    assert response.status_code == 200
    # `categories` is the one the user made — the system catalog is the install's, not theirs.
    assert response.json()["counts"] == {
        "accounts": 1,
        "transactions": 1,
        "categories": 1,
        "rules": 1,
        "recurring": 1,
        "goals": 1,
    }


def test_summary_of_an_empty_profile_is_all_zeroes(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")

    counts = client.get("/api/v1/database/summary", headers=headers).json()["counts"]

    assert set(counts.values()) == {0}


def test_reset_deletes_everything_the_user_owns_and_reports_it(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client, "amelie@example.com")
    with _session(tmp_path) as db:
        ids = _seed(db, "amelie@example.com")
        db.add(
            TaxParameter(
                user_id=None,
                tax_year=2025,
                key="pfu_income_tax_bps",
                int_value=1280,
                unit="bps",
            )
        )
        db.commit()

    response = client.post("/api/v1/database/reset", headers=headers)

    assert response.status_code == 200
    # What the confirmation listed, not the empty profile's zeroes.
    assert response.json()["counts"]["transactions"] == 1
    with _session(tmp_path) as db:
        for model in (Property, Mortgage, MortgageSimulation, TaxProfile, TaxBracket):
            assert db.scalars(select(model)).all() == []
        # The user's override went; the install's system parameter stayed.
        remaining = db.scalars(select(TaxParameter)).all()
        assert [(row.user_id, row.int_value) for row in remaining] == [(None, 1280)]
        assert db.get(Account, ids["account"]) is None
        assert db.get(Transaction, ids["transaction"]) is None
        assert db.get(Goal, ids["goal"]) is None
        assert db.scalars(select(GoalAllocation)).all() == []
        assert db.scalars(select(CategorizationRule)).all() == []
        assert db.scalars(select(RecurringSeries)).all() == []
        assert db.scalars(select(Category).where(Category.user_id == ids["user"])).all() == []
    after = client.get("/api/v1/database/summary", headers=headers).json()["counts"]
    assert set(after.values()) == {0}


def test_reset_keeps_the_system_catalog_and_the_profiles_settings(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client, "amelie@example.com")
    client.patch("/api/v1/settings", headers=headers, json={"ai_enabled": True})
    client.post("/api/v1/backup/export", headers=headers)
    before = client.get("/api/v1/settings", headers=headers).json()
    with _session(tmp_path) as db:
        _seed(db, "amelie@example.com")
        system_before = len(db.scalars(select(Category).where(Category.user_id.is_(None))).all())

    assert client.post("/api/v1/database/reset", headers=headers).status_code == 200

    assert client.get("/api/v1/settings", headers=headers).json() == before
    with _session(tmp_path) as db:
        system = db.scalars(select(Category).where(Category.user_id.is_(None))).all()
        assert len(system) == system_before
        assert db.scalars(select(UserSettings)).all() != []


def test_reset_restores_a_system_catalog_that_had_gone_missing(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client, "amelie@example.com")
    with _session(tmp_path) as db:
        db.execute(Category.__table__.delete().where(Category.user_id.is_(None)))
        db.commit()

    assert client.post("/api/v1/database/reset", headers=headers).status_code == 200

    with _session(tmp_path) as db:
        assert db.scalars(select(Category).where(Category.user_id.is_(None))).all() != []


def test_reset_leaves_other_profiles_untouched(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client, "amelie@example.com")
    _register(client, "bruno@example.com")
    with _session(tmp_path) as db:
        _seed(db, "amelie@example.com")
        bruno = _seed(db, "bruno@example.com")

    assert client.post("/api/v1/database/reset", headers=headers).status_code == 200

    with _session(tmp_path) as db:
        assert db.get(Account, bruno["account"]) is not None
        assert db.get(Transaction, bruno["transaction"]) is not None
        assert db.get(Goal, bruno["goal"]) is not None
        assert db.get(Mortgage, bruno["mortgage"]) is not None


def test_reset_is_refused_while_a_run_is_in_flight(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client, "amelie@example.com")
    with _session(tmp_path) as db:
        ids = _seed(db, "amelie@example.com")
        db.add(CategorizationRun(user_id=ids["user"], trigger="manual", status="running"))
        db.commit()

    response = client.post("/api/v1/database/reset", headers=headers)

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "RESET_RUN_ACTIVE"
    with _session(tmp_path) as db:
        assert db.get(Account, ids["account"]) is not None


def test_database_endpoints_require_auth(client: TestClient) -> None:
    assert client.get("/api/v1/database/summary").status_code == 401
    assert client.post("/api/v1/database/reset").status_code == 401
