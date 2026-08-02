"""Data access for `CategorizationRule` rows. The only place that queries this table."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.features.rules.models import CategorizationRule


class RuleRepository:
    """Queries and writes for categorization rules, always scoped to a user."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def list_by_user(self, user_id: str) -> list[CategorizationRule]:
        return list(
            self._db.scalars(
                select(CategorizationRule)
                .where(CategorizationRule.user_id == user_id)
                .order_by(CategorizationRule.priority)
            )
        )

    def list_enabled_by_user(self, user_id: str) -> list[CategorizationRule]:
        """Enabled rules in priority order — what the engine evaluates."""
        return list(
            self._db.scalars(
                select(CategorizationRule)
                .where(
                    CategorizationRule.user_id == user_id,
                    CategorizationRule.enabled.is_(True),
                )
                .order_by(CategorizationRule.priority)
            )
        )

    def get_by_id_for_user(self, rule_id: str, user_id: str) -> CategorizationRule | None:
        return self._db.scalar(
            select(CategorizationRule).where(
                CategorizationRule.id == rule_id, CategorizationRule.user_id == user_id
            )
        )

    def add(self, rule: CategorizationRule) -> CategorizationRule:
        self._db.add(rule)
        self._db.commit()
        self._db.refresh(rule)
        return rule

    def update(self, rule: CategorizationRule) -> CategorizationRule:
        self._db.commit()
        self._db.refresh(rule)
        return rule

    def delete(self, rule: CategorizationRule) -> None:
        self._db.delete(rule)
        self._db.commit()
