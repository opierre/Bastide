"""Tests for full backup export, inspect and restore."""

import io
import json
import zipfile
from datetime import date
from pathlib import Path
from typing import Any

import pytest
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
from app.features.rules.models import CategorizationRule
from app.features.transactions.models import Transaction
from tests.api import register as _register

PATRIMOINE_MEMBERS = (
    "properties.jsonl",
    "mortgages.jsonl",
    "mortgage_simulations.jsonl",
)


def _session(tmp_path: Path) -> Session:
    """A session on the `client` fixture's temp database."""
    engine = create_engine(f"sqlite:///{tmp_path / 'test.db'}")
    return sessionmaker(bind=engine)()


def _seed(db: Session, email: str) -> dict[str, str]:
    """Give the user one of everything; returns the ids the tests assert on."""
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
    run = CategorizationRun(user_id=user.id, trigger="manual", status="completed")
    db.add_all([transaction, rule, goal, run])
    db.flush()
    db.add(GoalAllocation(goal_id=goal.id, amount_minor=20_000, allocated_on=date(2026, 8, 20)))
    db.commit()
    return {"user": user.id, "account": account.id, "transaction": transaction.id}


def _seed_patrimoine(db: Session, user_id: str) -> dict[str, str]:
    """A property with the loan that financed it, and a simulation."""
    home = Property(
        user_id=user_id,
        label="Résidence principale",
        kind="primary_residence",
        market_value_minor=32_000_000,
        valued_on=date(2026, 6, 1),
    )
    db.add(home)
    db.flush()
    loan = Mortgage(
        user_id=user_id,
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
                user_id=user_id,
                label="T3 Nantes",
                property_price_minor=28_000_000,
                down_payment_minor=4_000_000,
                principal_minor=26_000_000,
                annual_rate_bps=330,
                insurance_monthly_minor=3_800,
                term_months=240,
                upfront_fees_minor=150_000,
            ),
        ]
    )
    db.commit()
    return {"property": home.id, "mortgage": loan.id}


def _drop_members(content: bytes, *members: str, format_version: int) -> bytes:
    """Copy an archive without `members`, stamped with an older `format_version`."""
    source = zipfile.ZipFile(io.BytesIO(content))
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as target:
        for member in source.namelist():
            if member in members:
                continue
            data = source.read(member)
            if member == "manifest.json":
                manifest = json.loads(data)
                manifest["format_version"] = format_version
                manifest["tables"] = {
                    name: count
                    for name, count in manifest["tables"].items()
                    if f"{name}.jsonl" not in members
                }
                data = json.dumps(manifest).encode()
            target.writestr(member, data)
    return buffer.getvalue()


def _export(client: TestClient, headers: dict[str, str]) -> bytes:
    response = client.post("/api/v1/backup/export", headers=headers)
    assert response.status_code == 200
    return response.content


def _upload(client: TestClient, path: str, headers: dict[str, str], content: bytes) -> Any:
    return client.post(
        f"/api/v1/backup/{path}",
        headers=headers,
        files={"file": ("sauvegarde.bastide", content, "application/zip")},
    )


def _rewrite(content: bytes, **changes: Any) -> bytes:
    """Copy an archive, replacing members (`name=bytes`) and manifest keys (`manifest={...}`)."""
    manifest_changes = changes.pop("manifest", {})
    source = zipfile.ZipFile(io.BytesIO(content))
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as target:
        for member in source.namelist():
            data = source.read(member)
            if member == "manifest.json":
                data = json.dumps({**json.loads(data), **manifest_changes}).encode()
            target.writestr(member, changes.get(member.replace(".", "_"), data))
    return buffer.getvalue()


def test_export_writes_a_manifest_and_one_jsonl_per_table(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client, "amelie@example.com")
    with _session(tmp_path) as db:
        ids = _seed(db, "amelie@example.com")

    response = client.post("/api/v1/backup/export", headers=headers)

    assert response.status_code == 200
    assert response.headers["content-type"] == "application/zip"
    summary = json.loads(response.headers["x-backup-summary"])
    assert summary["counts"] == {
        "accounts": 1,
        "transactions": 1,
        "categories": 1,
        "rules": 1,
        "recurring": 0,
        "goals": 1,
        "mortgages": 0,
        "properties": 0,
        "simulations": 0,
    }
    archive = zipfile.ZipFile(io.BytesIO(response.content))
    manifest = json.loads(archive.read("manifest.json"))
    assert manifest["format"] == "bastide-backup"
    assert manifest["format_version"] == 2
    assert manifest["currency"] == "EUR"
    assert "users.jsonl" not in archive.namelist()
    assert "auth_tokens.jsonl" not in archive.namelist()
    transactions = [json.loads(line) for line in archive.read("transactions.jsonl").splitlines()]
    assert transactions[0]["id"] == ids["transaction"]
    # Money stays signed integer minor units through the file.
    assert transactions[0]["amount_minor"] == -4_234
    assert isinstance(transactions[0]["amount_minor"], int)


def test_export_records_the_last_backup_time(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")
    assert client.get("/api/v1/settings", headers=headers).json()["last_backup_at"] is None

    summary = json.loads(
        client.post("/api/v1/backup/export", headers=headers).headers["x-backup-summary"]
    )

    last = client.get("/api/v1/settings", headers=headers).json()["last_backup_at"]
    assert last is not None
    assert last[:19] == summary["exported_at"][:19]


def test_export_carries_only_the_callers_rows(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client, "amelie@example.com")
    _register(client, "bruno@example.com")
    with _session(tmp_path) as db:
        _seed(db, "bruno@example.com")

    archive = zipfile.ZipFile(io.BytesIO(_export(client, headers)))

    for member in ("accounts.jsonl", "transactions.jsonl", "categories.jsonl", "goals.jsonl"):
        assert archive.read(member) == b""


def test_inspect_summarises_without_touching_data(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client, "amelie@example.com")
    with _session(tmp_path) as db:
        _seed(db, "amelie@example.com")
    content = _export(client, headers)

    response = _upload(client, "inspect", headers, content)

    assert response.status_code == 200
    body = response.json()
    assert body["counts"]["transactions"] == 1
    assert body["format_version"] == 2
    assert body["currency"] == "EUR"


def test_restore_replaces_the_users_data_with_the_archive(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client, "amelie@example.com")
    with _session(tmp_path) as db:
        ids = _seed(db, "amelie@example.com")
    content = _export(client, headers)
    # Diverge after the export: one extra account, and the original one removed from the list.
    with _session(tmp_path) as db:
        db.add(
            Account(
                user_id=ids["user"],
                name="Livret A",
                type="savings",
                institution="BNP",
                currency="EUR",
                opening_balance_minor=0,
                cached_balance_minor=0,
            )
        )
        db.commit()

    response = _upload(client, "restore", headers, content)

    assert response.status_code == 200
    with _session(tmp_path) as db:
        accounts = db.scalars(select(Account).where(Account.user_id == ids["user"])).all()
        assert [account.id for account in accounts] == [ids["account"]]
        transaction = db.get(Transaction, ids["transaction"])
        assert transaction is not None
        assert transaction.amount_minor == -4_234
        assert len(db.scalars(select(GoalAllocation)).all()) == 1


def test_backup_round_trips_the_patrimoine_tables(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client, "amelie@example.com")
    with _session(tmp_path) as db:
        user_id = db.scalars(select(User.id).where(User.email == "amelie@example.com")).one()
        ids = _seed_patrimoine(db, user_id)
    content = _export(client, headers)

    archive = zipfile.ZipFile(io.BytesIO(content))
    manifest = json.loads(archive.read("manifest.json"))
    for member in PATRIMOINE_MEMBERS:
        assert manifest["tables"][member.removesuffix(".jsonl")] == 1

    response = _upload(client, "restore", headers, content)
    assert response.status_code == 200
    counts = response.json()["counts"]
    assert {key: counts[key] for key in ("mortgages", "properties", "simulations")} == {
        "mortgages": 1,
        "properties": 1,
        "simulations": 1,
    }

    with _session(tmp_path) as db:
        loan = db.get(Mortgage, ids["mortgage"])
        assert loan is not None
        assert loan.property_id == ids["property"]
        assert loan.annual_rate_bps == 345
        assert db.get(Property, ids["property"]) is not None
        assert len(db.scalars(select(MortgageSimulation)).all()) == 1


def test_restore_ignores_the_members_of_the_removed_tax_tables(
    client: TestClient, tmp_path: Path
) -> None:
    """A format-2 archive exported while the tax feature existed still restores."""
    headers = _register(client, "amelie@example.com")
    with _session(tmp_path) as db:
        ids = _seed(db, "amelie@example.com")
    source = zipfile.ZipFile(io.BytesIO(_export(client, headers)))
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as older:
        for member in source.namelist():
            data = source.read(member)
            if member == "manifest.json":
                manifest = json.loads(data)
                manifest["tables"] |= {"tax_profiles": 1, "tax_brackets": 0, "tax_parameters": 0}
                data = json.dumps(manifest).encode()
            older.writestr(member, data)
        older.writestr(
            "tax_profiles.jsonl",
            json.dumps({"id": "p1", "user_id": ids["user"], "tax_year": 2025}) + "\n",
        )
        older.writestr("tax_brackets.jsonl", "")
        older.writestr("tax_parameters.jsonl", "")

    response = _upload(client, "restore", headers, buffer.getvalue())

    assert response.status_code == 200
    with _session(tmp_path) as db:
        assert db.get(Transaction, ids["transaction"]) is not None


def test_restore_of_a_version_1_archive_empties_the_patrimoine_tables(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client, "amelie@example.com")
    with _session(tmp_path) as db:
        ids = _seed(db, "amelie@example.com")
    older = _drop_members(_export(client, headers), *PATRIMOINE_MEMBERS, format_version=1)
    with _session(tmp_path) as db:
        _seed_patrimoine(db, ids["user"])

    response = _upload(client, "restore", headers, older)

    assert response.status_code == 200
    assert response.json()["counts"]["mortgages"] == 0
    with _session(tmp_path) as db:
        assert db.get(Transaction, ids["transaction"]) is not None
        assert db.scalars(select(Mortgage)).all() == []
        assert db.scalars(select(Property)).all() == []


def test_restore_rejects_a_version_2_archive_missing_a_patrimoine_table(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")
    crafted = _drop_members(_export(client, headers), "mortgages.jsonl", format_version=2)

    response = _upload(client, "restore", headers, crafted)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "BACKUP_INVALID"


def test_restore_keeps_the_install_s_last_backup_time(client: TestClient) -> None:
    headers = _register(client, "amelie@example.com")
    content = _export(client, headers)
    before = client.get("/api/v1/settings", headers=headers).json()["last_backup_at"]

    _upload(client, "restore", headers, content)

    assert client.get("/api/v1/settings", headers=headers).json()["last_backup_at"] == before


def test_restore_leaves_other_users_untouched(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client, "amelie@example.com")
    _register(client, "bruno@example.com")
    with _session(tmp_path) as db:
        bruno = _seed(db, "bruno@example.com")
    content = _export(client, headers)

    assert _upload(client, "restore", headers, content).status_code == 200

    with _session(tmp_path) as db:
        assert db.get(Account, bruno["account"]) is not None
        assert db.get(Transaction, bruno["transaction"]) is not None


def test_restore_rejects_a_newer_format_before_touching_data(
    client: TestClient, tmp_path: Path
) -> None:
    headers = _register(client, "amelie@example.com")
    with _session(tmp_path) as db:
        ids = _seed(db, "amelie@example.com")
    newer = _rewrite(_export(client, headers), manifest={"format_version": 99})

    for path in ("inspect", "restore"):
        response = _upload(client, path, headers, newer)
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "BACKUP_TOO_NEW"

    with _session(tmp_path) as db:
        assert db.get(Account, ids["account"]) is not None


@pytest.mark.parametrize("content", [b"not a zip", b""])
def test_restore_rejects_a_file_that_is_not_an_archive(client: TestClient, content: bytes) -> None:
    headers = _register(client, "amelie@example.com")

    response = _upload(client, "restore", headers, content)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "BACKUP_INVALID"


def test_restore_rejects_another_currency(client: TestClient) -> None:
    content = _export(client, _register(client, "amelie@example.com"))
    headers = _register(client, "bruno@example.com", currency="usd")

    response = _upload(client, "inspect", headers, content)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "BACKUP_CURRENCY_MISMATCH"


def test_restore_rolls_back_on_a_dangling_reference(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client, "amelie@example.com")
    with _session(tmp_path) as db:
        ids = _seed(db, "amelie@example.com")
    content = _export(client, headers)
    line = json.loads(zipfile.ZipFile(io.BytesIO(content)).read("transactions.jsonl"))
    line["account_id"] = "00000000-0000-0000-0000-000000000000"
    crafted = _rewrite(content, transactions_jsonl=json.dumps(line).encode())

    response = _upload(client, "restore", headers, crafted)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "BACKUP_INVALID"
    with _session(tmp_path) as db:
        # The delete that preceded the failing row was rolled back with it.
        assert db.get(Transaction, ids["transaction"]) is not None
        assert db.get(Account, ids["account"]) is not None


def test_restore_rejects_a_float_amount(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client, "amelie@example.com")
    with _session(tmp_path) as db:
        _seed(db, "amelie@example.com")
    content = _export(client, headers)
    line = json.loads(zipfile.ZipFile(io.BytesIO(content)).read("transactions.jsonl"))
    line["amount_minor"] = -42.34
    crafted = _rewrite(content, transactions_jsonl=json.dumps(line).encode())

    response = _upload(client, "restore", headers, crafted)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "BACKUP_INVALID"


def test_restore_into_another_user_conflicts_while_the_source_still_exists(
    client: TestClient, tmp_path: Path
) -> None:
    amelie = _register(client, "amelie@example.com")
    with _session(tmp_path) as db:
        _seed(db, "amelie@example.com")
    content = _export(client, amelie)
    bruno = _register(client, "bruno@example.com")

    response = _upload(client, "restore", bruno, content)

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "BACKUP_CONFLICT"


def test_restore_is_refused_while_a_run_is_in_flight(client: TestClient, tmp_path: Path) -> None:
    headers = _register(client, "amelie@example.com")
    with _session(tmp_path) as db:
        ids = _seed(db, "amelie@example.com")
    content = _export(client, headers)
    with _session(tmp_path) as db:
        db.add(CategorizationRun(user_id=ids["user"], trigger="manual", status="running"))
        db.commit()

    response = _upload(client, "restore", headers, content)

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "BACKUP_RUN_ACTIVE"


def test_backup_endpoints_require_auth(client: TestClient) -> None:
    assert client.post("/api/v1/backup/export").status_code == 401
    response = client.post(
        "/api/v1/backup/restore", files={"file": ("x.bastide", b"x", "application/zip")}
    )
    assert response.status_code == 401
