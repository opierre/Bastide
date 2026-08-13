"""Business logic for categorization rule CRUD and re-applying the rule engine."""

import re

from sqlalchemy import Select, select
from sqlalchemy.orm import Session, selectinload

from app.core.errors import NotFoundError, ValidationError
from app.features.accounts.models import Account
from app.features.categories.repository import CategoryRepository
from app.features.categories.service import CategoryNotFoundError
from app.features.rules.engine import match_category, matches
from app.features.rules.models import CategorizationRule
from app.features.rules.repository import RuleRepository
from app.features.rules.schemas import (
    MatchField,
    MatchType,
    RuleCreate,
    RuleFromTransactionRequest,
    RulePreviewRequest,
    RuleUpdate,
)
from app.features.rules.suggest import RuleSuggestion, suggest_rule
from app.features.transactions.models import Transaction
from app.features.transactions.repository import TransactionRepository
from app.features.transactions.service import TransactionNotFoundError

#: Examples shown next to a preview's count. Enough to recognise what the rule caught, few
#: enough that the modal stays a modal.
PREVIEW_SAMPLE_LIMIT = 3


class RuleNotFoundError(NotFoundError):
    """Raised when a rule doesn't exist or doesn't belong to the caller."""

    code = "RULE_NOT_FOUND"


class RulePatternInvalidError(ValidationError):
    """Raised when a `regex` pattern doesn't compile; carries the compile error in `details`."""

    code = "RULE_PATTERN_INVALID"


class RuleService:
    """Rule CRUD, scoped to a user, plus re-running the rule engine over transactions."""

    def __init__(
        self,
        repository: RuleRepository,
        transactions: TransactionRepository,
        categories: CategoryRepository,
        db: Session,
    ) -> None:
        self._repository = repository
        self._transactions = transactions
        self._categories = categories
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
        transactions = list(self._db.scalars(self._transactions_query(user_id, account_id)))

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

    def preview(self, user_id: str, data: RulePreviewRequest) -> tuple[int, list[Transaction]]:
        """Count the caller's transactions an unsaved rule would match, with a few examples.

        Evaluated by the rule engine itself, so the count is exactly the set of rows the saved
        rule would match. Note that a subsequent apply may change fewer rows than this: it
        leaves rows already carrying `source=user` alone, and rows this rule's category is
        already on need no change. Writes nothing.

        Raises:
            RulePatternInvalidError: `match_type` is `regex` and the pattern doesn't compile.
        """
        candidate = self._candidate_rule(user_id, data.match_field, data.match_type, data.pattern)
        query = (
            self._transactions_query(user_id, data.account_id)
            .options(selectinload(Transaction.category))
            .order_by(Transaction.booked_date.desc(), Transaction.id.desc())
        )

        match_count = 0
        samples: list[Transaction] = []
        for transaction in self._db.scalars(query):
            if not matches(transaction, candidate):
                continue
            match_count += 1
            if len(samples) < PREVIEW_SAMPLE_LIMIT:
                samples.append(transaction)
        return match_count, samples

    def suggest_for_transaction(self, user_id: str, transaction_id: str) -> RuleSuggestion:
        """Propose the rule that would have categorized one of the caller's transactions.

        Raises:
            TransactionNotFoundError: no such transaction, or it belongs to another user.
        """
        transaction = self._transactions.get_by_id_for_user(transaction_id, user_id)
        if transaction is None:
            raise TransactionNotFoundError("Transaction not found.")
        return suggest_rule(transaction)

    def create_from_transaction(
        self, user_id: str, data: RuleFromTransactionRequest
    ) -> tuple[CategorizationRule, int]:
        """Turn a user correction into a rule, so stage 1 handles the next occurrence.

        The rule and the correction that justifies it are written in one DB transaction: a rule
        without the correction would leave the row the user just fixed unfixed, and a correction
        without the rule would silently drop what the user asked to remember.

        The rule appends at the end of the priority order, so learning something never reorders
        what the user arranged deliberately. With `apply_now`, the P1 apply path then re-runs
        over the caller's transactions — honouring its own invariant that a row carrying
        `source=user` is never overridden, this one included.

        Returns:
            The created rule and the number of *other* transactions the apply step changed
            (0 when `apply_now` is false).

        Raises:
            RulePatternInvalidError: `match_type` is `regex` and the pattern doesn't compile.
            TransactionNotFoundError: no such transaction, or it belongs to another user.
            CategoryNotFoundError: no such category, or it is another user's.
        """
        _validate_pattern(data.match_type, data.pattern)

        transaction = self._transactions.get_by_id_for_user(data.transaction_id, user_id)
        if transaction is None:
            raise TransactionNotFoundError("Transaction not found.")
        if self._categories.get_visible_by_id_for_user(data.category_id, user_id) is None:
            raise CategoryNotFoundError("Category not found.")

        rule = CategorizationRule(
            user_id=user_id,
            priority=self._repository.next_priority(user_id),
            match_field=data.match_field,
            match_type=data.match_type,
            pattern=data.pattern,
            category_id=data.category_id,
            enabled=True,
        )
        self._repository.stage(rule)
        transaction.category_id = data.category_id
        transaction.categorization_source = "user"
        transaction.needs_review = False

        try:
            self._db.commit()
        except Exception:
            self._db.rollback()
            raise
        self._db.refresh(rule)

        recategorized_count = self.apply(user_id) if data.apply_now else 0
        return rule, recategorized_count

    def _candidate_rule(
        self, user_id: str, match_field: MatchField, match_type: MatchType, pattern: str
    ) -> CategorizationRule:
        """An in-memory rule for the engine to evaluate. Never added to the session.

        `category_id` is left blank: the engine's match predicate doesn't read it, and a preview
        has no category to speak of.
        """
        _validate_pattern(match_type, pattern)
        return CategorizationRule(
            user_id=user_id,
            priority=0,
            match_field=match_field,
            match_type=match_type,
            pattern=pattern,
            category_id="",
            enabled=True,
        )

    def _transactions_query(
        self, user_id: str, account_id: str | None
    ) -> Select[tuple[Transaction]]:
        query = (
            select(Transaction)
            .join(Account, Account.id == Transaction.account_id)
            .where(Account.user_id == user_id)
        )
        if account_id is not None:
            query = query.where(Transaction.account_id == account_id)
        return query


def _validate_pattern(match_type: MatchType, pattern: str) -> None:
    """Reject a `regex` pattern that doesn't compile.

    Raises:
        RulePatternInvalidError: the pattern is an invalid regular expression. The user is
            writing it in a modal, so the compile error travels in `details`.
    """
    if match_type != "regex":
        return
    try:
        re.compile(pattern)
    except re.error as exc:
        raise RulePatternInvalidError(
            "The pattern is not a valid regular expression.",
            {"pattern": pattern, "error": str(exc)},
        ) from exc
