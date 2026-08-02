"""Deterministic, priority-ordered categorization rule matching. Pure — no DB access."""

import re
from collections.abc import Sequence

from app.features.rules.models import CategorizationRule
from app.features.transactions.models import Transaction


def match_category(transaction: Transaction, rules: Sequence[CategorizationRule]) -> str | None:
    """Return the `category_id` of the first enabled rule (ascending priority) that matches.

    Returns None if no enabled rule matches (the caller leaves the transaction uncategorized).
    """
    for rule in sorted((r for r in rules if r.enabled), key=lambda r: r.priority):
        if _matches(transaction, rule):
            return rule.category_id
    return None


def _matches(transaction: Transaction, rule: CategorizationRule) -> bool:
    if rule.match_type == "range":
        return _matches_range(transaction.amount_minor, rule.pattern)

    value = _field_value(transaction, rule.match_field)
    if value is None:
        return False

    if rule.match_type == "contains":
        return rule.pattern.lower() in value.lower()
    if rule.match_type == "equals":
        return value.lower() == rule.pattern.lower()
    if rule.match_type == "regex":
        return re.search(rule.pattern, value) is not None
    return False


def _field_value(transaction: Transaction, match_field: str) -> str | None:
    if match_field == "description_clean":
        return transaction.description_clean
    if match_field == "merchant":
        return transaction.merchant
    if match_field == "amount":
        return str(transaction.amount_minor)
    return None


def _matches_range(amount_minor: int, pattern: str) -> bool:
    """Parse a `min:max` pattern; either side may be blank for an open-ended bound."""
    try:
        min_str, max_str = pattern.split(":", 1)
        minimum = int(min_str) if min_str else None
        maximum = int(max_str) if max_str else None
    except ValueError:
        return False
    if minimum is not None and amount_minor < minimum:
        return False
    return not (maximum is not None and amount_minor > maximum)
