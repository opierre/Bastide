"""Business logic for previewing, importing, and exporting rule packs.

Everything here funnels into ordinary `categorization_rules` rows and the P1 engine. There is
deliberately no parallel matching or apply path: an imported rule has to be indistinguishable
from a hand-written one the moment it lands, or the review queue and the rules editor would each
need to learn about packs.
"""

import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from sqlalchemy.orm import Session

from app.core.errors import NotFoundError, ValidationError
from app.features.categories.models import Category
from app.features.categories.repository import CategoryRepository
from app.features.rules.engine import match_category
from app.features.rules.models import CategorizationRule
from app.features.rules.packs.resolve import ResolvedEntry, resolve_pack
from app.features.rules.packs.schema import (
    DEFAULT_EXPORT_PACK_NAME,
    SUPPORTED_FORMAT_VERSION,
    BuiltinPackRead,
    OmissionReason,
    OmittedRuleRead,
    RulePack,
    RulePackEntry,
    RulePackSource,
)
from app.features.rules.repository import RuleRepository
from app.features.rules.service import PREVIEW_SAMPLE_LIMIT, RuleService
from app.features.transactions.models import Transaction
from app.features.transactions.repository import TransactionRepository

#: Where the bundled packs live. Shipped as data files rather than Python literals so a pack is
#: the same artifact whether it came with the app or arrived from a friend.
BUILTIN_DIR = Path(__file__).parent / "builtin"

#: The locales the pack format admits; a user whose locale is anything else exports without one,
#: since `locale` is advisory provenance and a wrong value is worse than none.
_PACK_LOCALES = frozenset({"fr", "en"})

#: The natural key an imported rule is deduplicated on: field, type, casefolded pattern, and
#: destination category. Casefolded because `contains`/`equals` match case-insensitively
#: (`engine.py`), so a case-sensitive key would admit duplicates the engine cannot tell apart.
type _DedupKey = tuple[str, str, str, str]


class BuiltinPackNotFoundError(NotFoundError):
    """Raised when `builtin_id` names no bundled pack."""

    code = "RULE_PACK_NOT_FOUND"


class RulePackInvalidError(ValidationError):
    """Raised when a bundled pack file on disk fails to parse — a packaging bug, not user input."""

    code = "RULE_PACK_INVALID"


@dataclass(frozen=True)
class PackPreview:
    """What importing a pack would do, and how much of the backlog it would resolve."""

    name: str
    total: int
    new_count: int
    duplicate_count: int
    unresolved: list[str]
    would_match_count: int
    samples: list[Transaction]


@dataclass(frozen=True)
class PackImport:
    """What importing a pack did."""

    created_count: int
    skipped_count: int
    unresolved: list[str]
    recategorized_count: int


@dataclass(frozen=True)
class PackExport:
    """A pack built from a user's rules, plus the rules the format could not carry."""

    pack: RulePack
    omitted: list[OmittedRuleRead]


class RulePackService:
    """Rule pack preview/import/export, always scoped to one user."""

    def __init__(
        self,
        rules: RuleRepository,
        categories: CategoryRepository,
        transactions: TransactionRepository,
        rule_service: RuleService,
        db: Session,
    ) -> None:
        self._rules = rules
        self._categories = categories
        self._transactions = transactions
        self._rule_service = rule_service
        self._db = db

    # --- bundled packs ----------------------------------------------------------------------

    def list_builtin(self) -> list[BuiltinPackRead]:
        """Summarise the bundled packs, so the frontend can offer one without a file picker."""
        return [
            BuiltinPackRead(
                id=pack_id, name=pack.name, locale=pack.locale, rule_count=len(pack.rules)
            )
            for pack_id, pack in sorted(_load_builtin_packs().items())
        ]

    def load_source(self, source: RulePackSource) -> RulePack:
        """Return the pack a request refers to, whether uploaded inline or bundled.

        Raises:
            BuiltinPackNotFoundError: `builtin_id` names no bundled pack.
        """
        if source.pack is not None:
            return source.pack
        packs = _load_builtin_packs()
        pack = packs.get(source.builtin_id or "")
        if pack is None:
            raise BuiltinPackNotFoundError("Rule pack not found.")
        return pack

    # --- preview ----------------------------------------------------------------------------

    def preview(self, user_id: str, pack: RulePack) -> PackPreview:
        """Report what an import would do, without writing anything.

        `new_count`, `duplicate_count` and `unresolved` are computed by the same code the import
        uses, so a preview never promises something the import then declines to do.

        `would_match_count` runs the **engine itself** over the caller's currently-uncategorized
        transactions with their existing enabled rules plus the pack's new ones. Not a `LIKE`
        query: `range` has no text equivalent, and first-match-wins means summing per-rule counts
        would double-count a transaction two rules both describe.
        """
        plan = self._plan(user_id, pack)
        existing_enabled = self._rules.list_enabled_by_user(user_id)
        candidates = _candidate_rules(user_id, plan.creatable, self._rules.next_priority(user_id))
        rules = [*existing_enabled, *candidates]

        would_match_count = 0
        samples: list[Transaction] = []
        for transaction in self._transactions.list_uncategorized_for_user(user_id):
            if match_category(transaction, rules) is None:
                continue
            would_match_count += 1
            if len(samples) < PREVIEW_SAMPLE_LIMIT:
                samples.append(transaction)

        return PackPreview(
            name=pack.name,
            total=len(pack.rules),
            new_count=len(plan.creatable),
            duplicate_count=plan.duplicate_count,
            unresolved=plan.unresolved,
            would_match_count=would_match_count,
            samples=samples,
        )

    # --- import -----------------------------------------------------------------------------

    def import_pack(self, user_id: str, pack: RulePack, apply_now: bool) -> PackImport:
        """Create one rule per resolvable, non-duplicate entry, in one DB transaction.

        All of them land or none do: a half-imported pack would leave the user with an arbitrary
        prefix of someone else's rules and no way to tell which.

        The rules append after everything the user already has (`max(priority) + 1`, ascending in
        pack order), so an imported rule never preempts one the user ordered deliberately. With
        `apply_now`, the existing P1 apply path then re-runs, honouring its invariant that a row
        carrying `source='user'` is never overridden.
        """
        plan = self._plan(user_id, pack)
        rules = _candidate_rules(user_id, plan.creatable, self._rules.next_priority(user_id))
        try:
            for rule in rules:
                self._rules.stage(rule)
            self._db.commit()
        except Exception:
            self._db.rollback()
            raise

        recategorized_count = self._rule_service.apply(user_id) if apply_now else 0
        return PackImport(
            created_count=len(rules),
            skipped_count=plan.duplicate_count,
            unresolved=plan.unresolved,
            recategorized_count=recategorized_count,
        )

    # --- export -----------------------------------------------------------------------------

    def export(self, user_id: str, locale: str, enabled_only: bool, name: str | None) -> PackExport:
        """Emit the caller's rules in pack format, resolving `category_id` back to its key.

        A rule pointing at a user-defined category has no key to emit, and a `regex` rule would
        be refused by the very importer this file targets. Both are omitted and reported rather
        than written out — a pack that fails its own import is worse than one that says what it
        left behind.
        """
        rules = self._rules.list_by_user(user_id)
        if enabled_only:
            rules = [rule for rule in rules if rule.enabled]

        by_id: dict[str, Category] = {
            category.id: category for category in self._categories.list_for_user(user_id)
        }

        entries: list[RulePackEntry] = []
        omitted: list[OmittedRuleRead] = []
        for rule in rules:
            reason = _export_blocker(rule, by_id.get(rule.category_id))
            if reason is not None:
                omitted.append(
                    OmittedRuleRead(rule_id=rule.id, pattern=rule.pattern, reason=reason)
                )
                continue
            category = by_id[rule.category_id]
            entries.append(
                RulePackEntry(
                    field=rule.match_field,  # ty: ignore[invalid-argument-type] — column is a
                    # plain str; the literal is enforced on the way in by `RuleCreate`.
                    type=rule.match_type,  # ty: ignore[invalid-argument-type] — same.
                    pattern=rule.pattern,
                    category_key=category.name,
                    enabled=rule.enabled,
                )
            )

        pack = RulePack(
            format_version=SUPPORTED_FORMAT_VERSION,
            name=name or DEFAULT_EXPORT_PACK_NAME,
            locale=locale if locale in _PACK_LOCALES else None,  # ty: ignore[invalid-argument-type]
            rules=entries,
        )
        return PackExport(pack=pack, omitted=omitted)

    # --- shared planning --------------------------------------------------------------------

    def _plan(self, user_id: str, pack: RulePack) -> _ImportPlan:
        """Resolve and deduplicate a pack. The single source of truth for preview and import.

        Deduplication runs against the user's existing rules *and* within the pack itself, so
        re-importing the same file creates nothing the second time and a pack that repeats
        itself does not repeat itself in the database either.
        """
        resolution = resolve_pack(pack, self._categories, user_id)

        seen: set[_DedupKey] = {_dedup_key(rule) for rule in self._rules.list_by_user(user_id)}
        creatable: list[ResolvedEntry] = []
        duplicate_count = 0
        for resolved in resolution.resolved:
            key = _entry_dedup_key(resolved)
            if key in seen:
                duplicate_count += 1
                continue
            seen.add(key)
            creatable.append(resolved)

        return _ImportPlan(
            creatable=creatable,
            duplicate_count=duplicate_count,
            unresolved=resolution.unresolved,
        )


@dataclass(frozen=True)
class _ImportPlan:
    """What a pack reduces to once resolved against a user's categories and existing rules."""

    creatable: list[ResolvedEntry]
    duplicate_count: int
    unresolved: list[str]


def _dedup_key(rule: CategorizationRule) -> _DedupKey:
    return (rule.match_field, rule.match_type, rule.pattern.casefold(), rule.category_id)


def _entry_dedup_key(resolved: ResolvedEntry) -> _DedupKey:
    return (
        resolved.entry.field,
        resolved.entry.type,
        resolved.entry.pattern.casefold(),
        resolved.category_id,
    )


def _candidate_rules(
    user_id: str, entries: list[ResolvedEntry], first_priority: int
) -> list[CategorizationRule]:
    """Build the rows an import would create, appended in pack order from ``first_priority``.

    Not added to the session — the caller decides whether these are staged for a real import or
    handed to the engine for a preview that must write nothing.
    """
    return [
        CategorizationRule(
            user_id=user_id,
            priority=first_priority + offset,
            match_field=resolved.entry.field,
            match_type=resolved.entry.type,
            pattern=resolved.entry.pattern,
            category_id=resolved.category_id,
            enabled=resolved.entry.enabled,
        )
        for offset, resolved in enumerate(entries)
    ]


def _export_blocker(rule: CategorizationRule, category: Category | None) -> OmissionReason | None:
    """Why ``rule`` cannot round-trip through the pack format, or None if it can."""
    if rule.match_type == "regex":
        return "regex"
    if category is None or not category.is_system:
        return "user_category"
    return None


@lru_cache(maxsize=1)
def _load_builtin_packs() -> dict[str, RulePack]:
    """Parse every bundled pack file once per process, keyed by filename stem.

    Cached because these files never change at runtime, and validated through the very models
    that validate an uploaded pack — a bundled pack that would fail its own import is a bug we
    want to hear about at boot, not in a user's report.

    Raises:
        RulePackInvalidError: a bundled file is not a valid pack.
    """
    packs: dict[str, RulePack] = {}
    for path in sorted(BUILTIN_DIR.glob("*.json")):
        try:
            packs[path.stem] = RulePack.model_validate(json.loads(path.read_text("utf-8")))
        except Exception as exc:
            raise RulePackInvalidError(
                "A bundled rule pack could not be read.", {"pack": path.name, "error": str(exc)}
            ) from exc
    return packs
