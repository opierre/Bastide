"""Business logic for categorization rule CRUD and re-applying the rule engine."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.features.accounts.models import Account
from app.features.rules.engine import match_category
from app.features.rules.models import CategorizationRule
from app.features.rules.repository import RuleRepository
from app.features.rules.schemas import RuleCreate, RuleUpdate
from app.features.transactions.models import Transaction


class RuleNotFoundError(NotFoundError):
    """Raised when a rule doesn't exist or doesn't belong to the caller."""

    code = "RULE_NOT_FOUND"


class RuleService:
    """Rule CRUD, scoped to a user, plus re-running the rule engine over transactions."""

    def __init__(self, repository: RuleRepository, db: Session) -> None:
        self._repository = repository
        self._db = db

    def list_for_user(self, user_id: str) -> list[CategorizationRule]:
        """List a user's rules in priority order."""
        return self._repository.list_by_user(user_id)

    def get(self, user_id: str, rule_id: str) -> CategorizationRule:
        """Fetch a single rule the user owns.

        Raises:
            RuleNotFoundError: no such rule, or it belongs to another user.
        """
        rule = self._repository.get_by_id_for_user(rule_id, user_id)
        if rule is None:
            raise RuleNotFoundError("Rule not found.")
        return rule

    def create(self, user_id: str, data: RuleCreate) -> CategorizationRule:
        """Create a new categorization rule."""
        rule = CategorizationRule(
            user_id=user_id,
            priority=data.priority,
            match_field=data.match_field,
            match_type=data.match_type,
            pattern=data.pattern,
            category_id=data.category_id,
            enabled=data.enabled,
        )
        return self._repository.add(rule)

    def update(self, user_id: str, rule_id: str, data: RuleUpdate) -> CategorizationRule:
        """Patch mutable fields on a rule.

        Raises:
            RuleNotFoundError: no such rule, or it belongs to another user.
        """
        rule = self.get(user_id, rule_id)
        if data.priority is not None:
            rule.priority = data.priority
        if data.match_field is not None:
            rule.match_field = data.match_field
        if data.match_type is not None:
            rule.match_type = data.match_type
        if data.pattern is not None:
            rule.pattern = data.pattern
        if data.category_id is not None:
            rule.category_id = data.category_id
        if data.enabled is not None:
            rule.enabled = data.enabled
        return self._repository.update(rule)

    def delete(self, user_id: str, rule_id: str) -> None:
        """Delete a rule.

        Raises:
            RuleNotFoundError: no such rule, or it belongs to another user.
        """
        rule = self.get(user_id, rule_id)
        self._repository.delete(rule)

    def apply(self, user_id: str, account_id: str | None = None) -> int:
        """Re-run the enabled rules over the user's transactions (optionally one account).

        Sets `category_id` + `source=rule` + `needs_review=False` on rows an enabled rule
        matches. Never touches rows with `source=user`, and leaves non-matching rows as-is.
        Returns the number of transactions actually changed.
        """
        rules = self._repository.list_enabled_by_user(user_id)
        transactions = self._transactions_for_user(user_id, account_id)

        recategorized_count = 0
        for transaction in transactions:
            if transaction.categorization_source == "user":
                continue

            category_id = match_category(transaction, rules)
            if category_id is None:
                continue

            already_applied = (
                transaction.category_id == category_id
                and transaction.categorization_source == "rule"
                and transaction.needs_review is False
            )
            if already_applied:
                continue

            transaction.category_id = category_id
            transaction.categorization_source = "rule"
            transaction.needs_review = False
            recategorized_count += 1

        self._db.commit()
        return recategorized_count

    def _transactions_for_user(self, user_id: str, account_id: str | None) -> list[Transaction]:
        query = (
            select(Transaction)
            .join(Account, Account.id == Transaction.account_id)
            .where(Account.user_id == user_id)
        )
        if account_id is not None:
            query = query.where(Transaction.account_id == account_id)
        return list(self._db.scalars(query))
