"""The rule pack wire format, and the request/response schemas around it.

Normative contract: `docs/schemas/rule-pack.v1.schema.json`. These models are the Python
enforcement of it, so keep the two in step.
"""

from typing import Any, Literal, Self

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.features.rules.schemas import MatchField
from app.features.transactions.schemas import TransactionRead

#: The one pack format this build reads. An unknown version is refused outright rather than
#: parsed best-effort: a pack we half-understand would silently drop the rules it didn't.
SUPPORTED_FORMAT_VERSION = 1

#: A pack's match types are a strict subset of the rules API's. `regex` is deliberately absent —
#: `engine.py` runs `re.search` unbounded against every transaction and Python's `re` cannot cap
#: backtracking, so a pattern arriving in someone else's file is a denial-of-service against the
#: importer's own machine in a way a hand-typed one is not. `contains`, `equals` and `range`
#: cover merchant matching; revisit only behind a real regex guard.
PackMatchType = Literal["contains", "equals", "range"]

#: A system category's i18n key, as seeded in `app/core/seed.py` (e.g. `category.food.groceries`).
CATEGORY_KEY_PATTERN = r"^category\.[a-z0-9_]+(\.[a-z0-9_]+)*$"

#: Enough entries for a thorough national pack, few enough that a hostile file can't make the
#: importer chew through an unbounded rule set on every transaction thereafter.
MAX_PACK_RULES = 1000


class RulePackEntry(BaseModel):
    """One rule in a pack: a match condition plus the system category key it assigns."""

    model_config = ConfigDict(extra="forbid")

    field: MatchField
    type: PackMatchType
    pattern: str = Field(min_length=1, max_length=255)
    category_key: str = Field(max_length=100, pattern=CATEGORY_KEY_PATTERN)
    enabled: bool = True
    comment: str | None = Field(default=None, max_length=200)

    @field_validator("type", mode="before")
    @classmethod
    def _reject_regex(cls, value: Any) -> Any:
        """Explain the refusal rather than letting the literal report a bare "not a valid enum".

        A refused pack is something the user has to act on — pick a different file, or edit this
        one — so the reason has to survive into the 422 the frontend renders.
        """
        if value == "regex":
            raise ValueError(
                "Regular-expression rules are not allowed in a rule pack; "
                "use 'contains', 'equals', or 'range'."
            )
        return value


class RulePack(BaseModel):
    """A portable set of categorization rules, version 1 of the format."""

    model_config = ConfigDict(extra="forbid")

    format_version: int
    name: str = Field(min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=500)
    locale: Literal["fr", "en"] | None = None
    source_url: str | None = Field(default=None, max_length=500)
    # The normative JSON schema says `minItems: 1` — a pack with no rules is not worth sharing.
    # It is not enforced here because export builds a `RulePack` too, and a user whose every
    # rule is unexportable (all `regex`, or all on user-defined categories) must still get a
    # well-formed body for the review sheet rather than a 500. Importing an empty pack then
    # simply creates nothing, which is the truthful outcome.
    rules: list[RulePackEntry] = Field(max_length=MAX_PACK_RULES)

    @field_validator("format_version")
    @classmethod
    def _supported_version(cls, value: int) -> int:
        """Refuse any version but ours, naming the one we support."""
        if value != SUPPORTED_FORMAT_VERSION:
            raise ValueError(
                f"Unsupported rule pack format_version {value}; "
                f"this version of Bastide reads format_version {SUPPORTED_FORMAT_VERSION}."
            )
        return value


class RulePackSource(BaseModel):
    """Where a pack comes from: an uploaded document, or one of the bundled packs by id."""

    pack: RulePack | None = None
    builtin_id: str | None = None

    @model_validator(mode="after")
    def _exactly_one_source(self) -> Self:
        if (self.pack is None) == (self.builtin_id is None):
            raise ValueError("Provide exactly one of 'pack' or 'builtin_id'.")
        return self


class RulePackImportRequest(RulePackSource):
    """A pack to import, and whether to re-run the rules over existing transactions after."""

    apply_now: bool = False


class BuiltinPackRead(BaseModel):
    """A bundled pack as listed by `GET /rules/packs/builtin`, without its rules."""

    id: str
    name: str
    locale: str | None
    rule_count: int


class RulePackPreviewResult(BaseModel):
    """What an import *would* do. Writes nothing; the numbers match the subsequent import."""

    name: str
    total: int
    new_count: int
    duplicate_count: int
    unresolved: list[str]
    would_match_count: int
    samples: list[TransactionRead]


class RulePackImportResult(BaseModel):
    """What an import did."""

    created_count: int
    skipped_count: int
    unresolved: list[str]
    recategorized_count: int


#: Why a rule cannot round-trip: it uses `regex` (which no importer will accept), or it points
#: at a user-defined category (which has no portable key). Both are v1 limits by design.
OmissionReason = Literal["regex", "user_category"]


class OmittedRuleRead(BaseModel):
    """A rule left out of an export because it cannot round-trip through the pack format."""

    rule_id: str
    pattern: str
    reason: OmissionReason


class RulePackExportResult(BaseModel):
    """The pack the UI shows for review, plus what it could not carry.

    The pack is a body rather than a download: patterns can hold personal detail — a landlord's
    name, `VIR SALAIRE DUPONT` — so the user reviews it before it becomes a file.
    """

    pack: RulePack
    omitted: list[OmittedRuleRead]


#: The name an export carries when the caller supplies none. Deliberately untranslated: it ends
#: up inside a file the user may share, not on a screen, so it is a constant, not a locale string.
DEFAULT_EXPORT_PACK_NAME = "Bastide rules"
