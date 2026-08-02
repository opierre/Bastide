"""Tests for the pure rule-matching engine: priority, first-match-wins, each match_type."""

from datetime import date

from app.features.rules.engine import match_category
from app.features.rules.models import CategorizationRule
from app.features.transactions.models import Transaction


def _rule(
    priority: int,
    match_field: str,
    match_type: str,
    pattern: str,
    category_id: str,
    enabled: bool = True,
) -> CategorizationRule:
    return CategorizationRule(
        user_id="user-1",
        priority=priority,
        match_field=match_field,
        match_type=match_type,
        pattern=pattern,
        category_id=category_id,
        enabled=enabled,
    )


def _transaction(
    description_clean: str = "SOME PURCHASE",
    merchant: str | None = None,
    amount_minor: int = -1000,
) -> Transaction:
    return Transaction(
        account_id="account-1",
        import_batch_id="batch-1",
        booked_date=date(2026, 1, 1),
        amount_minor=amount_minor,
        currency="EUR",
        description_raw=description_clean,
        description_clean=description_clean,
        merchant=merchant,
        categorization_source="uncategorized",
        dedup_hash="hash",
    )


def test_no_match_returns_none() -> None:
    transaction = _transaction(description_clean="RANDOM STORE")
    rules = [_rule(1, "description_clean", "contains", "CARREFOUR", "cat-groceries")]

    assert match_category(transaction, rules) is None


def test_first_match_wins_by_ascending_priority() -> None:
    transaction = _transaction(description_clean="CARREFOUR MARKET")
    rules = [
        _rule(2, "description_clean", "contains", "CARREFOUR", "cat-low-priority"),
        _rule(1, "description_clean", "contains", "CARREFOUR", "cat-high-priority"),
    ]

    assert match_category(transaction, rules) == "cat-high-priority"


def test_priority_order_is_independent_of_list_order() -> None:
    transaction = _transaction(description_clean="CARREFOUR MARKET")
    rules = [
        _rule(1, "description_clean", "contains", "CARREFOUR", "cat-high-priority"),
        _rule(2, "description_clean", "contains", "CARREFOUR", "cat-low-priority"),
    ]

    assert match_category(transaction, rules) == "cat-high-priority"


def test_disabled_rule_is_skipped() -> None:
    transaction = _transaction(description_clean="CARREFOUR MARKET")
    rules = [
        _rule(1, "description_clean", "contains", "CARREFOUR", "cat-disabled", enabled=False),
        _rule(2, "description_clean", "contains", "CARREFOUR", "cat-enabled"),
    ]

    assert match_category(transaction, rules) == "cat-enabled"


def test_contains_match_type() -> None:
    transaction = _transaction(description_clean="PAIEMENT CARREFOUR MARKET 75011")
    rules = [_rule(1, "description_clean", "contains", "carrefour", "cat-groceries")]

    assert match_category(transaction, rules) == "cat-groceries"


def test_equals_match_type() -> None:
    transaction = _transaction(merchant="Netflix")
    rules = [_rule(1, "merchant", "equals", "netflix", "cat-subscriptions")]

    assert match_category(transaction, rules) == "cat-subscriptions"


def test_equals_match_type_rejects_partial_match() -> None:
    transaction = _transaction(merchant="Netflix France")
    rules = [_rule(1, "merchant", "equals", "netflix", "cat-subscriptions")]

    assert match_category(transaction, rules) is None


def test_regex_match_type() -> None:
    transaction = _transaction(description_clean="VIR SEPA SALAIRE ACME CORP")
    rules = [_rule(1, "description_clean", "regex", r"^VIR SEPA SALAIRE", "cat-salary")]

    assert match_category(transaction, rules) == "cat-salary"


def test_range_match_type_on_amount() -> None:
    transaction = _transaction(amount_minor=-4500)
    rules = [_rule(1, "amount", "range", "-5000:-1000", "cat-mid-expense")]

    assert match_category(transaction, rules) == "cat-mid-expense"


def test_range_match_type_open_ended_bounds() -> None:
    big_income = _transaction(amount_minor=250_000)
    rules = [_rule(1, "amount", "range", "100000:", "cat-large-income")]

    assert match_category(big_income, rules) == "cat-large-income"


def test_range_match_type_amount_outside_range_does_not_match() -> None:
    transaction = _transaction(amount_minor=-100)
    rules = [_rule(1, "amount", "range", "-5000:-1000", "cat-mid-expense")]

    assert match_category(transaction, rules) is None


def test_merchant_none_does_not_match_contains_or_equals() -> None:
    transaction = _transaction(merchant=None)
    rules = [_rule(1, "merchant", "contains", "netflix", "cat-subscriptions")]

    assert match_category(transaction, rules) is None
