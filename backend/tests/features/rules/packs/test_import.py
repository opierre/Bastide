"""Tests for previewing and importing a rule pack."""

from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker

from app.core.seed import SYSTEM_CATEGORIES
from app.features.rules.models import CategorizationRule
from app.features.rules.packs.service import _load_builtin_packs
from app.features.rules.repository import RuleRepository
from tests.features.rules.packs.helpers import (
    GROCERIES,
    SALARY,
    TRANSIT,
    category_id_for_key,
    entry,
    import_pack,
    pack,
    preview,
)
from tests.features.rules.test_rules import (
    _create_account,
    _create_category,
    _create_rule,
    _insert_transaction,
    _register,
)

BUILTIN_ID = "fr-common.v1"


def _rules(client: TestClient, headers: dict[str, str]) -> list[dict]:
    return client.get("/api/v1/rules", headers=headers).json()


def _count_rules(tmp_path: Path) -> int:
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}", connect_args={"check_same_thread": False}
    )
    session = sessionmaker(bind=engine)()
    count = len(list(session.scalars(select(CategorizationRule))))
    session.close()
    return count


# --- ordering ------------------------------------------------------------------------------


def test_a_pack_imports_in_order_after_the_users_existing_rules(client: TestClient) -> None:
    headers, _ = _register(client)
    own_category = _create_category(client, headers)
    _create_rule(client, headers, own_category, priority=1, pattern="MON MAGASIN")
    _create_rule(client, headers, own_category, priority=2, pattern="MON AUTRE")

    _, body = import_pack(
        client,
        headers,
        pack=pack(
            entry("CARREFOUR", GROCERIES),
            entry("SNCF", TRANSIT),
            entry("VIREMENT SALAIRE", SALARY),
        ),
    )

    assert body["created_count"] == 3
    rules = _rules(client, headers)
    assert [rule["pattern"] for rule in rules] == [
        "MON MAGASIN",
        "MON AUTRE",
        "CARREFOUR",
        "SNCF",
        "VIREMENT SALAIRE",
    ]
    assert [rule["priority"] for rule in rules] == [1, 2, 3, 4, 5]


def test_an_imported_rule_never_preempts_a_user_ordered_one(client: TestClient) -> None:
    headers, _ = _register(client)
    own_category = _create_category(client, headers)
    _create_rule(client, headers, own_category, priority=9, pattern="CARREFOUR CITY")

    import_pack(client, headers, pack=pack(entry("CARREFOUR", GROCERIES)))

    imported = _rules(client, headers)[-1]
    assert imported["pattern"] == "CARREFOUR"
    assert imported["priority"] == 10


def test_an_entry_can_import_disabled(client: TestClient) -> None:
    headers, _ = _register(client)

    import_pack(client, headers, pack=pack(entry("CARREFOUR", GROCERIES, enabled=False)))

    assert _rules(client, headers)[0]["enabled"] is False


# --- deduplication -------------------------------------------------------------------------


def test_entries_repeated_within_a_pack_are_imported_once(client: TestClient) -> None:
    headers, _ = _register(client)
    payload = pack(
        entry("CARREFOUR", GROCERIES),
        entry("carrefour", GROCERIES),
        entry("CARREFOUR", GROCERIES),
    )

    _, body = import_pack(client, headers, pack=payload)

    assert body["created_count"] == 1
    assert body["skipped_count"] == 2


def test_an_entry_matching_an_existing_rule_is_skipped(client: TestClient) -> None:
    headers, _ = _register(client)
    groceries = category_id_for_key(client, headers, GROCERIES)
    _create_rule(client, headers, groceries, pattern="carrefour")

    _, body = import_pack(
        client, headers, pack=pack(entry("CARREFOUR", GROCERIES), entry("SNCF", TRANSIT))
    )

    assert body["created_count"] == 1
    assert body["skipped_count"] == 1
    assert [rule["pattern"] for rule in _rules(client, headers)] == ["carrefour", "SNCF"]


def test_the_same_pattern_on_a_different_category_is_not_a_duplicate(client: TestClient) -> None:
    headers, _ = _register(client)
    payload = pack(entry("CARREFOUR", GROCERIES), entry("CARREFOUR", TRANSIT))

    _, body = import_pack(client, headers, pack=payload)

    assert body["created_count"] == 2
    assert body["skipped_count"] == 0


def test_importing_the_same_pack_twice_creates_nothing_the_second_time(client: TestClient) -> None:
    headers, _ = _register(client)
    payload = pack(entry("CARREFOUR", GROCERIES), entry("SNCF", TRANSIT))

    _, first = import_pack(client, headers, pack=payload)
    _, second = import_pack(client, headers, pack=payload)

    assert first["created_count"] == 2
    assert second == {
        "created_count": 0,
        "skipped_count": 2,
        "unresolved": [],
        "recategorized_count": 0,
    }
    assert len(_rules(client, headers)) == 2


def test_reimporting_the_bundled_pack_is_a_no_op(client: TestClient) -> None:
    headers, _ = _register(client)

    _, first = import_pack(client, headers, builtin_id=BUILTIN_ID)
    _, second = import_pack(client, headers, builtin_id=BUILTIN_ID)

    assert first["created_count"] > 0
    assert second["created_count"] == 0
    assert second["skipped_count"] == first["created_count"]


# --- atomicity -----------------------------------------------------------------------------


def test_a_failure_mid_import_leaves_zero_rules_created(
    client: TestClient, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    headers, _ = _register(client)
    payload = pack(
        entry("CARREFOUR", GROCERIES),
        entry("SNCF", TRANSIT),
        entry("VIREMENT SALAIRE", SALARY),
    )

    staged = 0
    original = RuleRepository.stage

    def failing_stage(self: RuleRepository, rule: CategorizationRule) -> None:
        nonlocal staged
        staged += 1
        if staged == 3:
            raise RuntimeError("induced failure mid-import")
        original(self, rule)

    monkeypatch.setattr(RuleRepository, "stage", failing_stage)

    with pytest.raises(RuntimeError, match="induced failure"):
        import_pack(client, headers, pack=payload)

    monkeypatch.undo()
    assert _count_rules(tmp_path) == 0
    assert _rules(client, headers) == []


# --- apply_now -----------------------------------------------------------------------------


def test_apply_now_recategorizes_matching_transactions(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    _insert_transaction(tmp_path, user_id, account_id, "PAIEMENT CARREFOUR MARKET")
    _insert_transaction(tmp_path, user_id, account_id, "CB CARREFOUR CITY", amount_minor=-2500)
    _insert_transaction(tmp_path, user_id, account_id, "BOULANGERIE", amount_minor=-450)

    _, body = import_pack(client, headers, pack=pack(entry("CARREFOUR", GROCERIES)), apply_now=True)

    assert body["created_count"] == 1
    assert body["recategorized_count"] == 2


def test_apply_now_false_changes_nothing(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    _insert_transaction(tmp_path, user_id, account_id, "PAIEMENT CARREFOUR MARKET")

    _, body = import_pack(client, headers, pack=pack(entry("CARREFOUR", GROCERIES)))

    assert body["recategorized_count"] == 0
    page = client.get("/api/v1/transactions", headers=headers).json()
    assert page["items"][0]["category"] is None


def test_apply_now_never_overrides_a_user_categorized_row(
    client: TestClient, tmp_path: Path
) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    own_category = _create_category(client, headers)
    _insert_transaction(
        tmp_path,
        user_id,
        account_id,
        "CB CARREFOUR CITY",
        category_id=own_category,
        categorization_source="user",
        needs_review=False,
    )
    _insert_transaction(tmp_path, user_id, account_id, "PAIEMENT CARREFOUR", amount_minor=-2500)

    _, body = import_pack(client, headers, pack=pack(entry("CARREFOUR", GROCERIES)), apply_now=True)

    assert body["recategorized_count"] == 1
    items = client.get("/api/v1/transactions", headers=headers).json()["items"]
    corrected = [item for item in items if item["description_clean"] == "CB CARREFOUR CITY"][0]
    assert corrected["category"]["id"] == own_category
    assert corrected["categorization_source"] == "user"


# --- preview -------------------------------------------------------------------------------


def test_preview_counts_what_the_pack_would_categorize(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    _insert_transaction(tmp_path, user_id, account_id, "PAIEMENT CARREFOUR MARKET")
    _insert_transaction(tmp_path, user_id, account_id, "CB CARREFOUR CITY", amount_minor=-2500)
    _insert_transaction(tmp_path, user_id, account_id, "SNCF CONNECT", amount_minor=-4500)
    _insert_transaction(tmp_path, user_id, account_id, "MYSTERE", amount_minor=-100)

    _, body = preview(
        client, headers, pack=pack(entry("CARREFOUR", GROCERIES), entry("SNCF", TRANSIT))
    )

    assert body["would_match_count"] == 3
    assert body["total"] == 2
    assert body["new_count"] == 2


def test_preview_counts_a_transaction_two_rules_match_only_once(
    client: TestClient, tmp_path: Path
) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    _insert_transaction(tmp_path, user_id, account_id, "CB CARREFOUR CITY")

    _, body = preview(
        client, headers, pack=pack(entry("CARREFOUR", GROCERIES), entry("CB", TRANSIT))
    )

    assert body["would_match_count"] == 1


def test_preview_returns_at_most_three_samples(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    for index in range(5):
        _insert_transaction(
            tmp_path, user_id, account_id, "CB CARREFOUR CITY", amount_minor=-100 * (index + 1)
        )

    _, body = preview(client, headers, pack=pack(entry("CARREFOUR", GROCERIES)))

    assert body["would_match_count"] == 5
    assert len(body["samples"]) == 3
    assert all("CARREFOUR" in sample["description_clean"] for sample in body["samples"])


def test_preview_ignores_already_categorized_transactions(
    client: TestClient, tmp_path: Path
) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    own_category = _create_category(client, headers)
    _insert_transaction(
        tmp_path,
        user_id,
        account_id,
        "CB CARREFOUR CITY",
        category_id=own_category,
        categorization_source="user",
        needs_review=False,
    )
    _insert_transaction(tmp_path, user_id, account_id, "PAIEMENT CARREFOUR", amount_minor=-2500)

    _, body = preview(client, headers, pack=pack(entry("CARREFOUR", GROCERIES)))

    assert body["would_match_count"] == 1


def test_preview_persists_nothing(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    _insert_transaction(tmp_path, user_id, account_id, "CB CARREFOUR CITY")

    _, body = preview(client, headers, pack=pack(entry("CARREFOUR", GROCERIES)))

    assert body["new_count"] == 1
    assert _count_rules(tmp_path) == 0
    assert _rules(client, headers) == []
    assert (
        client.get("/api/v1/transactions", headers=headers).json()["items"][0]["category"] is None
    )


def test_preview_counts_agree_with_the_subsequent_import(client: TestClient) -> None:
    headers, _ = _register(client)
    groceries = category_id_for_key(client, headers, GROCERIES)
    _create_rule(client, headers, groceries, pattern="CARREFOUR")
    payload = pack(
        entry("CARREFOUR", GROCERIES),
        entry("SNCF", TRANSIT),
        entry("MYSTERE", "category.invented"),
    )

    _, previewed = preview(client, headers, pack=payload)
    _, imported = import_pack(client, headers, pack=payload)

    assert previewed["new_count"] == imported["created_count"] == 1
    assert previewed["duplicate_count"] == imported["skipped_count"] == 1
    assert previewed["unresolved"] == imported["unresolved"] == ["category.invented"]


def test_preview_never_sees_another_users_transactions(client: TestClient, tmp_path: Path) -> None:
    headers_a, _ = _register(client, "amelie@example.com")
    headers_b, user_id_b = _register(client, "bruno@example.com")
    account_id_b = _create_account(client, headers_b)
    _insert_transaction(tmp_path, user_id_b, account_id_b, "CB CARREFOUR CITY")

    _, body_a = preview(client, headers_a, pack=pack(entry("CARREFOUR", GROCERIES)))
    _, body_b = preview(client, headers_b, pack=pack(entry("CARREFOUR", GROCERIES)))

    assert body_a["would_match_count"] == 0
    assert body_b["would_match_count"] == 1


# --- the bundled pack ----------------------------------------------------------------------


def test_the_bundled_pack_is_listed(client: TestClient) -> None:
    headers, _ = _register(client)

    body = client.get("/api/v1/rules/packs/builtin", headers=headers).json()

    assert [entry_["id"] for entry_ in body] == [BUILTIN_ID]
    assert body[0]["locale"] == "fr"
    assert body[0]["rule_count"] > 0


def test_every_bundled_pack_key_resolves_on_a_freshly_seeded_user(client: TestClient) -> None:
    headers, _ = _register(client)

    _, body = import_pack(client, headers, builtin_id=BUILTIN_ID)

    bundled = _load_builtin_packs()[BUILTIN_ID]
    assert body["unresolved"] == []
    assert body["created_count"] == len(bundled.rules)


def test_every_bundled_pack_key_is_in_the_seed_catalog() -> None:
    """A unit-level guard, so a catalog rename fails here and not only through the API."""
    seeded = {seed.key for group in SYSTEM_CATEGORIES for seed in (group, *group.children)}

    keys = {rule.category_key for rule in _load_builtin_packs()[BUILTIN_ID].rules}

    assert keys <= seeded


def test_the_bundled_pack_imports_and_applies(client: TestClient, tmp_path: Path) -> None:
    headers, user_id = _register(client)
    account_id = _create_account(client, headers)
    _insert_transaction(tmp_path, user_id, account_id, "RETRAIT DAB 12/01 PARIS")
    _insert_transaction(tmp_path, user_id, account_id, "VIREMENT SALAIRE", amount_minor=285_000)
    _insert_transaction(tmp_path, user_id, account_id, "VIR EMIS M DUPONT", amount_minor=-3000)

    _, body = import_pack(client, headers, builtin_id=BUILTIN_ID, apply_now=True)

    assert body["recategorized_count"] == 2
    items = client.get("/api/v1/transactions", headers=headers).json()["items"]
    by_label = {item["description_clean"]: item for item in items}
    assert by_label["RETRAIT DAB 12/01 PARIS"]["category"]["name"] == "category.other.cash"
    assert by_label["VIREMENT SALAIRE"]["category"]["name"] == "category.income.salary"
    # A `VIR EMIS` is as likely a friend's reimbursement as a move between the user's own
    # accounts, so the pack deliberately carries no rule for it: the row reaches the review queue.
    assert by_label["VIR EMIS M DUPONT"]["category"] is None
    assert by_label["VIR EMIS M DUPONT"]["needs_review"] is True


def test_pack_import_requires_auth(client: TestClient) -> None:
    response = client.post("/api/v1/rules/packs/import", json={"builtin_id": BUILTIN_ID})

    assert response.status_code == 401


def test_listing_bundled_packs_requires_auth(client: TestClient) -> None:
    assert client.get("/api/v1/rules/packs/builtin").status_code == 401


def test_an_import_never_touches_another_users_rules(client: TestClient) -> None:
    headers_a, _ = _register(client, "amelie@example.com")
    headers_b, _ = _register(client, "bruno@example.com")

    import_pack(client, headers_a, pack=pack(entry("CARREFOUR", GROCERIES)))

    assert len(_rules(client, headers_a)) == 1
    assert _rules(client, headers_b) == []
