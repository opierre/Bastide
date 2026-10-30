"""The rule that files a deferred-debit card's monthly debit as a transfer.

A deferred card posts each purchase to its own account and settles the month's total on the
account it is drawn from in one debit. The purchases are the spending; the debit only moves
money between the two accounts, so it is filed under a `transfer`-kind category and counts as
neither income nor spending. That filing is an ordinary categorisation rule — one per card,
proposed from the card's number and confirmed by the user — rather than anything the import
guesses: every bank words the debit its own way, and a rule is what the user can read and fix.
"""

import re
from collections import Counter
from collections.abc import Iterable
from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import ValidationError
from app.features.accounts.models import Account
from app.features.categories.repository import CategoryRepository
from app.features.rules.engine import matches
from app.features.rules.models import CategorizationRule
from app.features.rules.service import validate_pattern
from app.features.transactions.models import Transaction

#: The system category a settlement is filed under (seeded in `app/core/seed.py`).
CARD_SETTLEMENT_CATEGORY_KEY = "category.finance.card_settlement"

#: Rules for a card's debit match the cleaned label; the other fields name no card.
SETTLEMENT_MATCH_FIELD = "description_clean"


class NotADeferredCardError(ValidationError):
    """Raised when a settlement rule is asked of an account that is not a deferred card."""

    code = "ACCOUNT_NOT_A_DEFERRED_CARD"


def card_digits(card: Account) -> str | None:
    """The last four digits of the card number — its bank id, else a number in its name.

    What a bank prints in the debit's label to say which card it settles (`X4821`).
    """
    for source in (card.ofx_account_id or "", card.name):
        digits = re.sub(r"\D", "", source)
        if len(digits) >= 4:
            return digits[-4:]
    return None


def suggest_settlement_pattern(
    digits: str | None, labels: Iterable[tuple[date, str]]
) -> str | None:
    """The label fragment that names this card's monthly debit, read from where it is paid.

    Every label carrying the card's digits is cut just after them — `DEPENSES CARTE X4821 AU
    29/04/26` gives `DEPENSES CARTE X4821` — and the fragment seen in the most distinct months
    wins: the debit comes once a month, where cash withdrawals and the yearly fee made with the
    same card (`X4821 CAFE…`, `COTISATION CARTE …4821`) don't. Ties go to the longer fragment,
    the more specific one. Without any such label, the digits alone; without digits, nothing.
    """
    if digits is None:
        return None
    months: dict[str, set[tuple[int, int]]] = {}
    for booked, label in labels:
        match = re.search(rf"^(.*?\S*{digits})", label)
        if match is None:
            continue
        months.setdefault(match.group(1).strip(), set()).add((booked.year, booked.month))
    if not months:
        return digits
    counts = Counter({fragment: len(seen) for fragment, seen in months.items()})
    return max(counts, key=lambda fragment: (counts[fragment], len(fragment)))


class SettlementRuleService:
    """Reads, proposes and saves the settlement rule of a user's deferred cards."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def rule_for(self, card: Account) -> CategorizationRule | None:
        """The card's settlement rule, or `None` while it has none."""
        return self._db.scalar(
            select(CategorizationRule).where(CategorizationRule.settlement_card_id == card.id)
        )

    def suggest(self, card: Account) -> str | None:
        """The pattern to propose for ``card``'s rule, read from the account that pays it.

        From the user's every non-card account while the card names no settlement account.

        Raises:
            NotADeferredCardError: ``card`` is not a deferred card.
        """
        _require_card(card)
        query = (
            select(Transaction.booked_date, Transaction.description_clean)
            .join(Account, Account.id == Transaction.account_id)
            .where(Account.user_id == card.user_id, Account.type != "deferred_card")
        )
        if card.settlement_account_id is not None:
            query = query.where(Transaction.account_id == card.settlement_account_id)
        labels = [(booked, label) for booked, label in self._db.execute(query)]
        return suggest_settlement_pattern(card_digits(card), labels)

    def save(self, card: Account, match_type: str, pattern: str) -> tuple[CategorizationRule, int]:
        """Create or replace ``card``'s rule, then file what it matches. Committed.

        A new rule goes ahead of every other: it names one card, so it is the most specific
        rule the user has. Applied at once over the user's transactions, so the debits already
        imported stop counting as spending now rather than at the next import; rows the user
        filed by hand stay theirs. Returns the rule and how many rows it moved.

        Raises:
            NotADeferredCardError: ``card`` is not a deferred card.
            RulePatternInvalidError: a `regex` pattern that doesn't compile.
        """
        _require_card(card)
        validate_pattern(match_type, pattern)
        category = CategoryRepository(self._db).list_system_by_names_for_user(
            [CARD_SETTLEMENT_CATEGORY_KEY], card.user_id
        )[0]

        rule = self.rule_for(card)
        if rule is None:
            first = self._db.scalar(
                select(CategorizationRule.priority)
                .where(CategorizationRule.user_id == card.user_id)
                .order_by(CategorizationRule.priority)
                .limit(1)
            )
            rule = CategorizationRule(
                user_id=card.user_id,
                priority=0 if first is None else first - 1,
                settlement_card_id=card.id,
            )
            self._db.add(rule)
        rule.match_field = SETTLEMENT_MATCH_FIELD
        rule.match_type = match_type
        rule.pattern = pattern
        rule.category_id = category.id
        rule.enabled = True

        moved = 0
        for transaction in self._db.scalars(
            select(Transaction)
            .join(Account, Account.id == Transaction.account_id)
            .where(
                Account.user_id == card.user_id,
                Transaction.categorization_source != "user",
            )
        ):
            if not matches(transaction, rule) or (
                transaction.category_id == category.id
                and transaction.categorization_source == "rule"
                and not transaction.needs_review
            ):
                continue
            transaction.category_id = category.id
            transaction.categorization_source = "rule"
            transaction.needs_review = False
            moved += 1

        self._db.commit()
        self._db.refresh(rule)
        return rule, moved


def _require_card(account: Account) -> None:
    if account.type != "deferred_card":
        raise NotADeferredCardError("Only a deferred card has a settlement rule.")
