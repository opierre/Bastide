"""Data access for rules, their logos and imported built-in packs. The only place querying them."""

from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session, undefer

from app.features.rules.models import CategorizationRule, RuleLogo, RulePackImport


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

    def next_priority(self, user_id: str) -> int:
        """One past the user's highest priority, so a new rule appends instead of preempting."""
        highest = self._db.scalar(
            select(func.max(CategorizationRule.priority)).where(
                CategorizationRule.user_id == user_id
            )
        )
        return 1 if highest is None else highest + 1

    def stage(self, rule: CategorizationRule) -> None:
        """Add a rule to the session *without* committing.

        For callers that own the transaction boundary because the rule has to land together
        with something else — see `RuleService.create_from_transaction`.
        """
        self._db.add(rule)

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

    def get_logo(self, rule: CategorizationRule) -> RuleLogo | None:
        """The rule's logo with its bytes, which listing rules leaves unloaded."""
        return self._db.scalar(
            select(RuleLogo).where(RuleLogo.rule_id == rule.id).options(undefer(RuleLogo.image))
        )

    def logo_images(self, user_id: str, rule_ids: list[str]) -> dict[str, bytes]:
        """The stored PNG of each of these rules that has a logo, by rule id, in one query."""
        if not rule_ids:
            return {}
        rows = self._db.execute(
            select(RuleLogo.rule_id, RuleLogo.image)
            .join(CategorizationRule, CategorizationRule.id == RuleLogo.rule_id)
            .where(CategorizationRule.user_id == user_id, RuleLogo.rule_id.in_(rule_ids))
        )
        return {rule_id: image for rule_id, image in rows.tuples()}

    def save_logo(self, rule: CategorizationRule, logo: RuleLogo) -> CategorizationRule:
        """Give the rule this logo, replacing any earlier one."""
        if rule.logo is None:
            rule.logo = logo
        else:
            rule.logo.image = logo.image
            rule.logo.content_type = logo.content_type
            rule.logo.updated_at = logo.updated_at
        return self.update(rule)

    def delete_logo(self, rule: CategorizationRule) -> CategorizationRule:
        rule.logo = None
        return self.update(rule)

    def imported_builtin_ids(self, user_id: str) -> set[str]:
        """The ids of the built-in packs the user has imported."""
        return set(
            self._db.scalars(
                select(RulePackImport.builtin_id).where(RulePackImport.user_id == user_id)
            )
        )

    def stage_pack_import(self, user_id: str, builtin_id: str, now: datetime) -> None:
        """Record, *without* committing, that the user imported a built-in pack.

        Staged so it lands in the same transaction as the pack's rules. A pack already recorded
        keeps its first row.
        """
        recorded = self._db.scalar(
            select(RulePackImport.id).where(
                RulePackImport.user_id == user_id, RulePackImport.builtin_id == builtin_id
            )
        )
        if recorded is None:
            self._db.add(RulePackImport(user_id=user_id, builtin_id=builtin_id, imported_at=now))
