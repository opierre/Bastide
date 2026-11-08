"""Rule logos: normalizing an upload, and finding which logo a transaction or series shows.

A transaction does not record which rule categorized it (a user correction, a model guess or
a later rule edit would make that record stale anyway), so the logo is resolved when the row
is read: the first enabled rule, in priority order, that has a logo and matches the row.
"""

from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from datetime import datetime
from http import HTTPStatus
from typing import Protocol

from app.core import images
from app.core.errors import ValidationError
from app.features.rules.engine import RuleSubject, matches
from app.features.rules.models import CategorizationRule
from app.features.rules.repository import RuleRepository

LOGO_SIZE = 256
LOGO_CONTENT_TYPE = images.PNG_CONTENT_TYPE
MAX_UPLOAD_BYTES = images.MAX_UPLOAD_BYTES
MAX_PIXELS = images.MAX_PIXELS


class RuleLogoTooLargeError(ValidationError):
    """Raised when an uploaded logo is over `MAX_UPLOAD_BYTES` or `MAX_PIXELS`."""

    code = "RULE_LOGO_TOO_LARGE"
    status_code = HTTPStatus.REQUEST_ENTITY_TOO_LARGE


class RuleLogoInvalidImageError(ValidationError):
    """Raised when an upload isn't a PNG, JPEG or WebP picture that decodes."""

    code = "RULE_LOGO_INVALID_IMAGE"


def normalize_logo(data: bytes) -> bytes:
    """Decode an uploaded logo, fit it whole inside a square and re-encode it as a PNG.

    Padded rather than cropped: many logos are wide wordmarks, and a crop would cut off their
    ends. The padding is transparent, so the chip's own background shows around the logo.

    Raises:
        RuleLogoTooLargeError: the file or its pixel count is over the limit.
        RuleLogoInvalidImageError: the bytes aren't a PNG, JPEG or WebP picture.
    """
    return images.square_png(
        data,
        LOGO_SIZE,
        too_large=lambda: RuleLogoTooLargeError(
            "The picture is too large.",
            details={"max_bytes": MAX_UPLOAD_BYTES, "max_pixels": MAX_PIXELS},
        ),
        invalid=lambda: RuleLogoInvalidImageError(
            "The file is not a PNG, JPEG or WebP picture.",
            details={"accepted": sorted(images.ACCEPTED_FORMATS)},
        ),
        max_bytes=MAX_UPLOAD_BYTES,
        max_pixels=MAX_PIXELS,
        fit="pad",
    )


class LogoCarrier(Protocol):
    """A response that shows a logo: a transaction or a series."""

    logo_rule_id: str | None
    logo_updated_at: datetime | None


class TransactionCarrier(LogoCarrier, RuleSubject, Protocol):
    """A transaction response: it shows a logo and is itself what the rules read."""


class SeriesCarrier(LogoCarrier, Protocol):
    """A series response, identified so its latest charge can be looked up."""

    @property
    def id(self) -> str: ...


@dataclass(frozen=True)
class LogoRef:
    """Which rule's logo to show, and its version, so a client can cache the picture by it."""

    rule_id: str
    updated_at: datetime


class RuleLogoResolver:
    """Finds the logo a row shows, for one user. Loads that user's rules once, on first use."""

    def __init__(self, repository: RuleRepository, user_id: str) -> None:
        self._repository = repository
        self._user_id = user_id
        self._rules: list[CategorizationRule] | None = None

    def resolve(self, subject: RuleSubject) -> LogoRef | None:
        """The logo of the first enabled rule with one that matches `subject`, if any."""
        if self._rules is None:
            # Enabled, in priority order; `logo` comes with them, without its bytes.
            self._rules = [
                rule
                for rule in self._repository.list_enabled_by_user(self._user_id)
                if rule.logo is not None
            ]
        for rule in self._rules:
            if matches(subject, rule):
                assert rule.logo is not None
                return LogoRef(rule_id=rule.id, updated_at=rule.logo.updated_at)
        return None

    def fill(self, carrier: LogoCarrier, subject: RuleSubject | None) -> None:
        """Set `carrier`'s logo reference from `subject`; none when there is no subject."""
        ref = self.resolve(subject) if subject is not None else None
        carrier.logo_rule_id = ref.rule_id if ref is not None else None
        carrier.logo_updated_at = ref.updated_at if ref is not None else None

    def fill_rows[T: TransactionCarrier](self, rows: Iterable[T]) -> list[T]:
        """Fill each transaction response from its own fields; returns them as a list."""
        filled = list(rows)
        for row in filled:
            self.fill(row, row)
        return filled

    def fill_series[T: SeriesCarrier](
        self, rows: Iterable[T], latest: Mapping[str, RuleSubject]
    ) -> list[T]:
        """Fill each series response from its latest charge, keyed by series id in `latest`.

        A series has no merchant of its own a rule could read, so it shows the logo its most
        recent charge would; a series with no charge shows none.
        """
        filled = list(rows)
        for row in filled:
            self.fill(row, latest.get(row.id))
        return filled
