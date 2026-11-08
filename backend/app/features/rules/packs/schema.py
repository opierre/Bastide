"""The rule pack wire format, and the request/response schemas around it.

Normative contract: `docs/schemas/rule-pack.v1.schema.json`. These models are the Python
enforcement of it, so keep the two in step.
"""

import base64
import binascii
from typing import Annotated, Any, Literal, Self
from urllib.parse import urlsplit

from pydantic import (
    BaseModel,
    ConfigDict,
    Discriminator,
    Field,
    Tag,
    field_validator,
    model_validator,
)

from app.features.rules.logos import MAX_UPLOAD_BYTES
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

#: Largest embedded logo, decoded: the same limit as a logo uploaded by hand.
MAX_LOGO_BYTES = MAX_UPLOAD_BYTES

#: Largest total of logo bytes one pack may bring, decoded: its embedded logos when the pack is
#: validated, then embedded plus downloaded ones during an import. A normalized logo is a
#: 256x256 PNG of a few dozen KB, so this fits hundreds of them while keeping a hostile pack
#: from making the importer hold or fetch an unbounded amount of pictures.
MAX_PACK_LOGO_BYTES = 20 * 1024 * 1024

#: The one host a linked logo may point at. Anything else is refused when the pack is
#: validated, so importing someone else's pack can never make this machine contact a server
#: they chose.
ALLOWED_LOGO_HOST = "upload.wikimedia.org"
#: The path a linked logo must sit under: Wikimedia Commons, whose files are all freely
#: licensed. The same host serves the non-free fair-use files of each Wikipedia under other
#: paths (`/wikipedia/en/`, `/wikipedia/fr/`), which a pack must not redistribute.
ALLOWED_LOGO_PATH_PREFIX = "/wikipedia/commons/"
ALLOWED_LOGO_URL_PREFIX = f"https://{ALLOWED_LOGO_HOST}{ALLOWED_LOGO_PATH_PREFIX}"


def is_allowed_logo_url(url: str) -> bool:
    """Whether ``url`` is an `https://upload.wikimedia.org/wikipedia/commons/...` file link.

    The authority must be exactly the allowed host: no user info, no port, no other spelling
    (backslash, whitespace, control character) a URL parser might read differently from the
    HTTP client. The path must sit under Commons, with no dot segment (plain or
    percent-encoded) that a client could resolve to somewhere else on the host.
    """
    if not url.isascii() or any(ch.isspace() or not ch.isprintable() or ch == "\\" for ch in url):
        return False
    parts = urlsplit(url)
    path = parts.path
    return (
        parts.scheme == "https"
        and parts.netloc == ALLOWED_LOGO_HOST
        and path.startswith(ALLOWED_LOGO_PATH_PREFIX)
        and len(path) > len(ALLOWED_LOGO_PATH_PREFIX)
        and "%2e" not in path.lower()
        and not any(segment in (".", "..") for segment in path.split("/"))
    )


def embedded_logo_size(data: str) -> int:
    """The decoded size of a padded base64 string, without decoding it."""
    return len(data) // 4 * 3 - (len(data) - len(data.rstrip("=")))


class EmbeddedLogo(BaseModel):
    """A logo carried inside the pack: a PNG, JPEG or WebP picture, base64-encoded."""

    model_config = ConfigDict(extra="forbid")

    data: str = Field(min_length=4)

    @field_validator("data")
    @classmethod
    def _valid_base64_within_cap(cls, value: str) -> str:
        """Refuse a logo over `MAX_LOGO_BYTES` before decoding it, then refuse bad base64."""
        if embedded_logo_size(value) > MAX_LOGO_BYTES:
            raise ValueError(f"An embedded logo may not exceed {MAX_LOGO_BYTES} bytes.")
        try:
            base64.b64decode(value, validate=True)
        except (binascii.Error, ValueError) as exc:
            raise ValueError("An embedded logo must be standard, padded base64.") from exc
        return value

    def image(self) -> bytes:
        """The picture's bytes, still to go through `normalize_logo`."""
        return base64.b64decode(self.data, validate=True)


class LinkedLogo(BaseModel):
    """A logo the pack points at: a Wikimedia Commons file, its licence and where it is from.

    Downloaded only when the user asks for it at import (`download_logos`).
    """

    model_config = ConfigDict(extra="forbid")

    url: str = Field(max_length=500)
    license: str = Field(min_length=1, max_length=100)
    source: str = Field(min_length=1, max_length=500)

    @field_validator("url")
    @classmethod
    def _allowed_host(cls, value: str) -> str:
        if not is_allowed_logo_url(value):
            raise ValueError(
                f"A linked logo must be a Wikimedia Commons file: {ALLOWED_LOGO_URL_PREFIX}..."
            )
        return value


def _logo_form(value: Any) -> str:
    """Pick the logo form from its keys, so a refusal names the form the author meant."""
    if isinstance(value, dict):
        return "link" if "url" in value else "data"
    return "link" if isinstance(value, LinkedLogo) else "data"


#: A pack entry's logo: embedded (`{"data": ...}`) or linked (`{"url", "license", "source"}`).
type PackLogo = Annotated[
    Annotated[EmbeddedLogo, Tag("data")] | Annotated[LinkedLogo, Tag("link")],
    Discriminator(_logo_form),
]


class RulePackEntry(BaseModel):
    """One rule in a pack: a match condition plus the system category key it assigns."""

    model_config = ConfigDict(extra="forbid")

    field: MatchField
    type: PackMatchType
    pattern: str = Field(min_length=1, max_length=255)
    category_key: str = Field(max_length=100, pattern=CATEGORY_KEY_PATTERN)
    enabled: bool = True
    comment: str | None = Field(default=None, max_length=200)
    logo: PackLogo | None = None

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

    @model_validator(mode="after")
    def _embedded_logos_within_cap(self) -> Self:
        """Refuse a pack whose embedded logos add up to more than `MAX_PACK_LOGO_BYTES`."""
        total = sum(
            embedded_logo_size(rule.logo.data)
            for rule in self.rules
            if isinstance(rule.logo, EmbeddedLogo)
        )
        if total > MAX_PACK_LOGO_BYTES:
            raise ValueError(
                f"A rule pack's embedded logos may not exceed {MAX_PACK_LOGO_BYTES} bytes in all."
            )
        return self


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
    """A pack to import, whether to re-run the rules after, and whether to fetch linked logos."""

    apply_now: bool = False
    # Off by default: a linked logo is fetched from Wikimedia only when the user says so.
    download_logos: bool = False


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
    #: Logos the import would attach: on new rules, and on matching rules that have none yet.
    logo_count: int
    #: How many of those are links, attached only when the import downloads them.
    logo_download_count: int


#: Why a logo was not attached: not a PNG/JPEG/WebP picture, over a size cap, or its download
#: failed (unreachable, timeout, error status, redirect off the allowed host).
LogoFailureReason = Literal["invalid_image", "too_large", "download_failed"]


class LogoFailureRead(BaseModel):
    """A pack logo that could not be attached. Its rule was imported regardless."""

    #: The entry's position in the pack's `rules`, from 0.
    index: int
    pattern: str
    reason: LogoFailureReason


class RulePackImportResult(BaseModel):
    """What an import did."""

    created_count: int
    skipped_count: int
    unresolved: list[str]
    recategorized_count: int
    #: Logos stored: on new rules, and on matching rules that had none.
    logo_count: int
    #: Linked logos left out because the import was not asked to download them.
    logo_skipped_count: int
    logo_failures: list[LogoFailureRead]


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
