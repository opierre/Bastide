"""Business logic for categorization rule CRUD."""

from app.core.errors import NotFoundError
from app.features.rules.models import CategorizationRule
from app.features.rules.repository import RuleRepository
from app.features.rules.schemas import RuleCreate, RuleUpdate


class RuleNotFoundError(NotFoundError):
    """Raised when a rule doesn't exist or doesn't belong to the caller."""

    code = "RULE_NOT_FOUND"


class RuleService:
    """Rule CRUD, scoped to a user."""

    def __init__(self, repository: RuleRepository) -> None:
        self._repository = repository

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
