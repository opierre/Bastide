"""Business logic for previewing, importing, and exporting rule packs.

Everything here funnels into ordinary `categorization_rules` rows and the P1 engine. There is
deliberately no parallel matching or apply path: an imported rule has to be indistinguishable
from a hand-written one the moment it lands, or the review queue and the rules editor would each
need to learn about packs.
"""

import base64
import json
from collections.abc import Callable, Iterable
from dataclasses import dataclass
from datetime import UTC, datetime
from functools import lru_cache
from pathlib import Path
from typing import Protocol

from sqlalchemy.orm import Session

from app.core.errors import NotFoundError, ValidationError
from app.features.categories.models import Category
from app.features.categories.repository import CategoryRepository
from app.features.rules.engine import match_category
from app.features.rules.logos import (
    LOGO_CONTENT_TYPE,
    RuleLogoInvalidImageError,
    RuleLogoTooLargeError,
    normalize_logo,
)
from app.features.rules.models import CategorizationRule, RuleLogo
from app.features.rules.packs.download import LogoDownloadError, LogoFetcher, LogoTooLargeError
from app.features.rules.packs.resolve import ResolvedEntry, resolve_pack
from app.features.rules.packs.schema import (
    DEFAULT_EXPORT_PACK_NAME,
    MAX_PACK_LOGO_BYTES,
    SUPPORTED_FORMAT_VERSION,
    BuiltinPackRead,
    EmbeddedLogo,
    LinkedLogo,
    LogoFailureRead,
    LogoFailureReason,
    OmissionReason,
    OmittedRuleRead,
    RulePack,
    RulePackEntry,
    RulePackSource,
    embedded_logo_size,
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
    logo_count: int
    logo_download_count: int


@dataclass(frozen=True)
class PackImport:
    """What importing a pack did."""

    created_count: int
    skipped_count: int
    unresolved: list[str]
    recategorized_count: int
    logo_count: int
    logo_skipped_count: int
    logo_failures: list[LogoFailureRead]


@dataclass(frozen=True)
class ImportedRules:
    """What the rules phase of an import did, reported before the logos are downloaded."""

    created_count: int
    skipped_count: int
    unresolved_count: int
    recategorized_count: int


class ImportProgress(Protocol):
    """Hears how an import advances: rules committed, then each logo download settling."""

    def rules_imported(self, rules: ImportedRules, logo_total: int) -> None:
        """The rules are committed; ``logo_total`` distinct logos are about to be downloaded."""
        ...

    def logo_fetched(self, *, failed: bool) -> None:
        """One more distinct logo URL settled, downloaded or not."""
        ...


@dataclass(frozen=True)
class PackExport:
    """A pack built from a user's rules, plus the rules the format could not carry."""

    pack: RulePack
    omitted: list[OmittedRuleRead]
    logo_count: int = 0
    logo_bytes: int = 0
    logos_too_large: bool = False


class RulePackService:
    """Rule pack preview/import/export, always scoped to one user."""

    def __init__(
        self,
        rules: RuleRepository,
        categories: CategoryRepository,
        transactions: TransactionRepository,
        rule_service: RuleService,
        db: Session,
        logo_fetcher: LogoFetcher,
        clock: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._rules = rules
        self._categories = categories
        self._transactions = transactions
        self._rule_service = rule_service
        self._db = db
        self._logo_fetcher = logo_fetcher
        self._clock = clock

    # --- bundled packs ----------------------------------------------------------------------

    def list_builtin(self, user_id: str) -> list[BuiltinPackRead]:
        """Summarise the bundled packs, so the frontend can offer one without a file picker.

        Each says whether the user has already imported it, so the app stops offering it.
        """
        imported = self._rules.imported_builtin_ids(user_id)
        return [
            BuiltinPackRead(
                id=pack_id,
                name=pack.name,
                locale=pack.locale,
                rule_count=len(pack.rules),
                imported=pack_id in imported,
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
            logo_count=len(plan.logos),
            logo_download_count=sum(isinstance(p.logo, LinkedLogo) for p in plan.logos),
        )

    # --- import -----------------------------------------------------------------------------

    async def import_pack(
        self,
        user_id: str,
        pack: RulePack,
        apply_now: bool,
        download_logos: bool = False,
        progress: ImportProgress | None = None,
        builtin_id: str | None = None,
    ) -> PackImport:
        """Import the pack's rules, then download the logos it links to.

        First, one DB transaction creates one rule per resolvable, non-duplicate entry, with
        the embedded logos: all of them land or none do, since a half-imported pack would leave
        the user with an arbitrary prefix of someone else's rules and no way to tell which.

        The rules append after everything the user already has (`max(priority) + 1`, ascending in
        pack order), so an imported rule never preempts one the user ordered deliberately. With
        `apply_now`, the existing P1 apply path then re-runs, honouring its invariant that a row
        carrying `source='user'` is never overridden.

        Then, only with `download_logos`, the linked logos are downloaded (the slow part, which
        is why the rules do not wait for it) and stored in a second transaction. Every logo goes
        through `normalize_logo`, on the new rules and on a duplicate's matching rule only when
        it has none: an existing logo is never replaced, including one set while the downloads
        ran. A logo that fails is reported and leaves its rule imported without it.

        ``progress``, when given, hears when the rules are in and as each download settles.

        ``builtin_id`` names the bundled pack being imported, if it is one: the import is then
        recorded with the rules, so the pack is listed as imported from then on.
        """
        plan = self._plan(user_id, pack)
        rules = _candidate_rules(user_id, plan.creatable, self._rules.next_priority(user_id))
        embedded = [p for p in plan.logos if isinstance(p.logo, EmbeddedLogo)]
        linked = [p for p in plan.logos if isinstance(p.logo, LinkedLogo)]

        embedded_images, embedded_failures = _normalize_all(
            (planned, planned.logo.image())
            for planned in embedded
            if isinstance(planned.logo, EmbeddedLogo)
        )
        now = self._clock()
        try:
            for planned, image in embedded_images:
                target = planned.rule if planned.rule is not None else rules[planned.new_offset]
                target.logo = RuleLogo(image=image, content_type=LOGO_CONTENT_TYPE, updated_at=now)
            for rule in rules:
                self._rules.stage(rule)
            if builtin_id is not None:
                self._rules.stage_pack_import(user_id, builtin_id, now)
            self._db.commit()
        except Exception:
            self._db.rollback()
            raise
        # Read once committed, so the logo phase can find each target again by id.
        targets = [
            planned.rule.id if planned.rule is not None else rules[planned.new_offset].id
            for planned in linked
        ]

        recategorized_count = self._rule_service.apply(user_id) if apply_now else 0
        links = list(dict.fromkeys(_link(p) for p in linked)) if download_logos else []
        if progress is not None:
            progress.rules_imported(
                ImportedRules(
                    created_count=len(rules),
                    skipped_count=plan.duplicate_count,
                    unresolved_count=len(plan.unresolved),
                    recategorized_count=recategorized_count,
                ),
                logo_total=len(links),
            )

        linked_images: list[tuple[_PlannedLogo, bytes]] = []
        linked_failures: list[LogoFailureRead] = []
        if links:
            linked_images, linked_failures = await self._download_logos(
                user_id,
                linked,
                targets,
                links,
                embedded_bytes=_embedded_bytes(embedded),
                progress=progress,
            )

        return PackImport(
            created_count=len(rules),
            skipped_count=plan.duplicate_count,
            unresolved=plan.unresolved,
            recategorized_count=recategorized_count,
            logo_count=len(embedded_images) + len(linked_images),
            logo_skipped_count=0 if download_logos else len(linked),
            logo_failures=sorted([*embedded_failures, *linked_failures], key=lambda f: f.index),
        )

    async def _download_logos(
        self,
        user_id: str,
        linked: list[_PlannedLogo],
        targets: list[str],
        links: list[str],
        *,
        embedded_bytes: int,
        progress: ImportProgress | None,
    ) -> tuple[list[tuple[_PlannedLogo, bytes]], list[LogoFailureRead]]:
        """Download, normalize and store the linked logos; return the stored ones and failures.

        Downloads share what is left of `MAX_PACK_LOGO_BYTES` once the embedded logos (already
        capped by the schema) are counted. A target rule deleted, or given a logo, while the
        downloads ran is left alone: neither stored nor reported as a failure.
        """

        def on_result(_url: str, result: bytes | LogoDownloadError) -> None:
            if progress is not None:
                progress.logo_fetched(failed=isinstance(result, LogoDownloadError))

        fetched = await self._logo_fetcher.fetch_all(
            links, MAX_PACK_LOGO_BYTES - embedded_bytes, on_result
        )

        failures: list[LogoFailureRead] = []
        candidates: list[tuple[_PlannedLogo, bytes]] = []
        for planned in linked:
            result = fetched.get(_link(planned), LogoDownloadError("Not fetched."))
            if isinstance(result, LogoTooLargeError):
                failures.append(_failure(planned, "too_large"))
            elif isinstance(result, LogoDownloadError):
                failures.append(_failure(planned, "download_failed"))
            else:
                candidates.append((planned, result))
        images, normalize_failures = _normalize_all(candidates)

        target_ids = {p.index: rule_id for p, rule_id in zip(linked, targets, strict=True)}
        stored: list[tuple[_PlannedLogo, bytes]] = []
        now = self._clock()
        try:
            for planned, image in images:
                target = self._rules.get_by_id_for_user(target_ids[planned.index], user_id)
                if target is None or target.logo is not None:
                    continue
                target.logo = RuleLogo(image=image, content_type=LOGO_CONTENT_TYPE, updated_at=now)
                stored.append((planned, image))
            self._db.commit()
        except Exception:
            self._db.rollback()
            raise
        return stored, [*failures, *normalize_failures]

    # --- export -----------------------------------------------------------------------------

    def export(
        self,
        user_id: str,
        locale: str,
        enabled_only: bool,
        name: str | None,
        include_logos: bool = False,
    ) -> PackExport:
        """Emit the caller's rules in pack format, resolving `category_id` back to its key.

        A rule pointing at a user-defined category has no key to emit, and a `regex` rule would
        be refused by the very importer this file targets. Both are omitted and reported rather
        than written out — a pack that fails its own import is worse than one that says what it
        left behind.

        With `include_logos`, each exported rule that has a logo carries its stored PNG,
        embedded. When those logos add up to more than `MAX_PACK_LOGO_BYTES` the pack carries
        none of them and says so (`logos_too_large`): import would refuse the whole file, and
        keeping an arbitrary subset would silently drop the rest.
        """
        rules = self._rules.list_by_user(user_id)
        if enabled_only:
            rules = [rule for rule in rules if rule.enabled]

        by_id: dict[str, Category] = {
            category.id: category for category in self._categories.list_for_user(user_id)
        }

        exportable: list[tuple[CategorizationRule, Category]] = []
        omitted: list[OmittedRuleRead] = []
        for rule in rules:
            reason = _export_blocker(rule, by_id.get(rule.category_id))
            if reason is not None:
                omitted.append(
                    OmittedRuleRead(rule_id=rule.id, pattern=rule.pattern, reason=reason)
                )
                continue
            exportable.append((rule, by_id[rule.category_id]))

        images: dict[str, bytes] = {}
        if include_logos:
            with_logo = [rule.id for rule, _ in exportable if rule.logo is not None]
            images = self._rules.logo_images(user_id, with_logo)
        logo_bytes = sum(len(image) for image in images.values())
        logos_too_large = logo_bytes > MAX_PACK_LOGO_BYTES
        if logos_too_large:
            images = {}

        entries = [
            RulePackEntry(
                field=rule.match_field,  # ty: ignore[invalid-argument-type] — column is a
                # plain str; the literal is enforced on the way in by `RuleCreate`.
                type=rule.match_type,  # ty: ignore[invalid-argument-type] — same.
                pattern=rule.pattern,
                category_key=category.name,
                enabled=rule.enabled,
                logo=_embed(images[rule.id]) if rule.id in images else None,
            )
            for rule, category in exportable
        ]

        pack = RulePack(
            format_version=SUPPORTED_FORMAT_VERSION,
            name=name or DEFAULT_EXPORT_PACK_NAME,
            locale=locale if locale in _PACK_LOCALES else None,  # ty: ignore[invalid-argument-type]
            rules=entries,
        )
        return PackExport(
            pack=pack,
            omitted=omitted,
            logo_count=len(images),
            logo_bytes=logo_bytes,
            logos_too_large=logos_too_large,
        )

    # --- shared planning --------------------------------------------------------------------

    def _plan(self, user_id: str, pack: RulePack) -> _ImportPlan:
        """Resolve and deduplicate a pack. The single source of truth for preview and import.

        Deduplication runs against the user's existing rules *and* within the pack itself, so
        re-importing the same file creates nothing the second time and a pack that repeats
        itself does not repeat itself in the database either.

        Each rule the import ends up with — new, or the user's own that a duplicate entry
        matches — gets at most one logo: the first entry naming one, and none at all on an
        existing rule that already has a logo.
        """
        resolution = resolve_pack(pack, self._categories, user_id)

        existing: dict[_DedupKey, CategorizationRule] = {}
        for rule in self._rules.list_by_user(user_id):
            existing.setdefault(_dedup_key(rule), rule)
        new_offsets: dict[_DedupKey, int] = {}
        creatable: list[ResolvedEntry] = []
        logos: list[_PlannedLogo] = []
        with_logo: set[_DedupKey] = set()
        duplicate_count = 0
        for resolved in resolution.resolved:
            key = _entry_dedup_key(resolved)
            if key in existing or key in new_offsets:
                duplicate_count += 1
            else:
                new_offsets[key] = len(creatable)
                creatable.append(resolved)

            logo = resolved.entry.logo
            if logo is None or key in with_logo:
                continue
            existing_rule = existing.get(key)
            if existing_rule is not None and existing_rule.logo is not None:
                continue
            with_logo.add(key)
            logos.append(
                _PlannedLogo(
                    index=resolved.index,
                    pattern=resolved.entry.pattern,
                    logo=logo,
                    rule=existing_rule,
                    new_offset=new_offsets.get(key, 0),
                )
            )

        return _ImportPlan(
            creatable=creatable,
            duplicate_count=duplicate_count,
            unresolved=resolution.unresolved,
            logos=logos,
        )


@dataclass(frozen=True)
class _PlannedLogo:
    """A pack logo and the rule it goes on: one of the user's (`rule`) or a new one."""

    index: int
    pattern: str
    logo: EmbeddedLogo | LinkedLogo
    #: The user's existing rule, which has no logo yet; `None` for a rule the import creates.
    rule: CategorizationRule | None
    #: The new rule's position among the import's created rules, when `rule` is `None`.
    new_offset: int


@dataclass(frozen=True)
class _ImportPlan:
    """What a pack reduces to once resolved against a user's categories and existing rules."""

    creatable: list[ResolvedEntry]
    duplicate_count: int
    unresolved: list[str]
    logos: list[_PlannedLogo]


def _link(planned: _PlannedLogo) -> str:
    """The URL of a planned linked logo."""
    assert isinstance(planned.logo, LinkedLogo)
    return planned.logo.url


def _embedded_bytes(embedded: list[_PlannedLogo]) -> int:
    """The decoded size of the embedded logos, which the downloads' budget is reduced by."""
    return sum(
        embedded_logo_size(p.logo.data) for p in embedded if isinstance(p.logo, EmbeddedLogo)
    )


def _failure(planned: _PlannedLogo, reason: LogoFailureReason) -> LogoFailureRead:
    return LogoFailureRead(index=planned.index, pattern=planned.pattern, reason=reason)


def _normalize_all(
    raw_logos: Iterable[tuple[_PlannedLogo, bytes]],
) -> tuple[list[tuple[_PlannedLogo, bytes]], list[LogoFailureRead]]:
    """Normalize each raw logo to the stored PNG, or report why it could not be."""
    images: list[tuple[_PlannedLogo, bytes]] = []
    failures: list[LogoFailureRead] = []
    for planned, raw in raw_logos:
        try:
            images.append((planned, normalize_logo(raw)))
        except RuleLogoTooLargeError:
            failures.append(_failure(planned, "too_large"))
        except RuleLogoInvalidImageError:
            failures.append(_failure(planned, "invalid_image"))
    return images, failures


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


def _embed(image: bytes) -> EmbeddedLogo:
    """A stored logo as the pack carries it: standard, padded base64."""
    return EmbeddedLogo(data=base64.b64encode(image).decode("ascii"))


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


def build_pack_service(db: Session, logo_fetcher: LogoFetcher) -> RulePackService:
    """A `RulePackService` on ``db``: a request's session, or a background run's own."""
    return RulePackService(
        RuleRepository(db),
        CategoryRepository(db),
        TransactionRepository(db),
        RuleService(RuleRepository(db), TransactionRepository(db), CategoryRepository(db), db),
        db,
        logo_fetcher,
    )
