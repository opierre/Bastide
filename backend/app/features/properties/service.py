"""Business logic for declared properties: CRUD, the held share, and the rent/regime matrix.

A property is declared, never observed: the app has no statement to read one from (§4c). It is
one entity because two features need it — the IFI base (§16) and net worth (§18) — so the share
arithmetic lives here once and neither of them keeps its own copy of a valuation.
"""

from datetime import date
from typing import Any

from app.core.errors import NotFoundError, ValidationError
from app.features.auth.models import User
from app.features.properties.models import Property
from app.features.properties.repository import PropertyRepository
from app.features.properties.schemas import (
    PropertyCreate,
    PropertyDetail,
    PropertyRead,
    PropertyUpdate,
)

_BPS_PER_UNIT = 10_000

#: The regime under which deductible charges are a meaningful figure (§16).
REEL = "reel"

#: The only nature that may carry rent fields; a vacant one carrying none is a real state.
RENTAL = "rental"

#: The three coupled columns, validated as a set rather than one at a time.
_RENT_FIELDS = ("annual_rent_minor", "annual_charges_minor", "property_regime")


class PropertyNotFoundError(NotFoundError):
    """Raised when a property doesn't exist or doesn't belong to the caller."""

    code = "PROPERTY_NOT_FOUND"


class PropertyValuationInFutureError(ValidationError):
    """Raised when `valued_on` is ahead of today.

    A valuation dated tomorrow is a typo, and §18's series leans on this date to caveat the
    net-worth history — so it is refused rather than carried into a chart as fact.
    """

    code = "PROPERTY_VALUATION_IN_FUTURE"


class PropertyRentOnNonRentalError(ValidationError):
    """Raised when a rent field is declared on a nature that is not `rental`."""

    code = "PROPERTY_RENT_ON_NON_RENTAL"


class PropertyRegimeRequiresRentError(ValidationError):
    """Raised when a regime is declared without the rent it is supposed to tax."""

    code = "PROPERTY_REGIME_REQUIRES_RENT"


class PropertyRentRequiresRegimeError(ValidationError):
    """Raised when rent is declared without a regime.

    §16 taxes property income down one of two roads chosen by the regime; with none declared it
    would have to pick one for the user, which is the silence this matrix exists to refuse.
    """

    code = "PROPERTY_RENT_REQUIRES_REGIME"


class PropertyChargesRequireReelError(ValidationError):
    """Raised when deductible charges are declared outside the `reel` regime.

    Under `micro_foncier` the 30 % abattement replaces real charges (§16), so a property
    carrying both is a contradiction the estimate would silently resolve one way or the other.
    """

    code = "PROPERTY_CHARGES_REQUIRE_REEL"


def held_share_minor(amount_minor: int, ownership_bps: int) -> int:
    """`amount_minor * ownership_bps / 10000`, rounded half-up.

    The only place this arithmetic lives: §16's IFI base and §18's assets read the figure, they
    do not recompute it. Integer throughout, as money always is (root `CLAUDE.md`).
    """
    return (2 * amount_minor * ownership_bps + _BPS_PER_UNIT) // (2 * _BPS_PER_UNIT)


def to_read(prop: Property, currency: str) -> PropertyRead:
    """The property with its derived share figures. Nothing here is stored."""
    share = held_share_minor(prop.market_value_minor, prop.ownership_bps)
    acquisition_delta = (
        share - held_share_minor(prop.acquisition_price_minor, prop.ownership_bps)
        if prop.acquisition_price_minor is not None
        else None
    )
    return PropertyRead(
        id=prop.id,
        label=prop.label,
        # ty: ignore[invalid-argument-type] — the columns are plain str; the Literals are
        # enforced by the create/update schemas, which are the only writers of these fields.
        kind=prop.kind,
        market_value_minor=prop.market_value_minor,
        valued_on=prop.valued_on,
        ownership_bps=prop.ownership_bps,
        acquisition_price_minor=prop.acquisition_price_minor,
        acquired_on=prop.acquired_on,
        annual_rent_minor=prop.annual_rent_minor,
        annual_charges_minor=prop.annual_charges_minor,
        # ty: ignore[invalid-argument-type] — see `kind`.
        property_regime=prop.property_regime,
        archived=prop.archived,
        currency=currency,
        user_share_value_minor=share,
        acquisition_delta_minor=acquisition_delta,
        created_at=prop.created_at,
        updated_at=prop.updated_at,
    )


def check_rent_fields(
    kind: str,
    annual_rent_minor: int | None,
    annual_charges_minor: int | None,
    property_regime: str | None,
) -> None:
    """Refuse every rent/regime/charges combination §16 could not read unambiguously.

    A `rental` carrying none of the three is left alone: a vacant rental is a real state.

    Raises:
        PropertyRentOnNonRentalError: a rent field on a nature that is not `rental`.
        PropertyRegimeRequiresRentError: a regime without rent.
        PropertyRentRequiresRegimeError: rent without a regime.
        PropertyChargesRequireReelError: charges outside `reel`.
    """
    if kind != RENTAL and (
        annual_rent_minor is not None
        or annual_charges_minor is not None
        or property_regime is not None
    ):
        raise PropertyRentOnNonRentalError(
            "Rent fields are only accepted on a rental property.",
            details={"kind": kind, "fields": list(_RENT_FIELDS)},
        )
    if property_regime is not None and annual_rent_minor is None:
        raise PropertyRegimeRequiresRentError(
            "A property regime requires an annual rent.",
            details={"property_regime": property_regime},
        )
    if annual_rent_minor is not None and property_regime is None:
        raise PropertyRentRequiresRegimeError(
            "An annual rent requires a property regime.",
            details={"property_regime": None},
        )
    if annual_charges_minor is not None and property_regime != REEL:
        raise PropertyChargesRequireReelError(
            "Deductible charges are only accepted under the 'reel' regime.",
            details={"property_regime": property_regime},
        )


class PropertyService:
    """Property CRUD and the derived held share, scoped to a user."""

    def __init__(self, repository: PropertyRepository) -> None:
        self._repository = repository

    def list_for_user(self, user: User, archived: bool = False) -> list[PropertyRead]:
        """The user's properties with their share figures, oldest first.

        Archived ones are absent unless asked for by name with `?archived=true`: they leave
        every aggregate (§16's IFI base, §18's assets) but are never destroyed.
        """
        return [
            to_read(prop, user.currency)
            for prop in self._repository.list_for_user(user.id, archived)
        ]

    def get(self, user: User, property_id: str) -> PropertyDetail:
        """One property with the loans pointing at it.

        Raises:
            PropertyNotFoundError: no such property, or it belongs to another user.
        """
        return self._detail(self._owned(user.id, property_id), user.currency)

    def create(self, user: User, data: PropertyCreate, today: date) -> PropertyDetail:
        """Declare a property. Currency is the user's; no per-property currency exists (§4c).

        Raises:
            PropertyValuationInFutureError: `valued_on` is ahead of `today`.
            PropertyRentOnNonRentalError: a rent field on a non-rental nature.
            PropertyRegimeRequiresRentError: a regime without rent.
            PropertyRentRequiresRegimeError: rent without a regime.
            PropertyChargesRequireReelError: charges outside `reel`.
        """
        self._check_valued_on(data.valued_on, today)
        check_rent_fields(
            data.kind,
            data.annual_rent_minor,
            data.annual_charges_minor,
            data.property_regime,
        )
        prop = Property(user_id=user.id, archived=False, **data.model_dump())
        return self._detail(self._repository.add(prop), user.currency)

    def update(
        self, user: User, property_id: str, data: PropertyUpdate, today: date
    ) -> PropertyDetail:
        """Patch a property, including archiving and unarchiving through `archived`.

        The patch is validated against the merged row before anything is assigned, so a
        rejected edit leaves the property exactly as it was. A "nouvelle estimation" is this
        call carrying `market_value_minor` and `valued_on` together (§4c: one declared value).

        Raises:
            PropertyNotFoundError: no such property, or it belongs to another user.
            PropertyValuationInFutureError: `valued_on` is ahead of `today`.
            PropertyRentOnNonRentalError: a rent field on a non-rental nature.
            PropertyRegimeRequiresRentError: a regime without rent.
            PropertyRentRequiresRegimeError: rent without a regime.
            PropertyChargesRequireReelError: charges outside `reel`.
        """
        prop = self._owned(user.id, property_id)
        changes: dict[str, Any] = data.model_dump(exclude_none=True)
        if "valued_on" in changes:
            self._check_valued_on(changes["valued_on"], today)
        check_rent_fields(
            **{field: changes.get(field, getattr(prop, field)) for field in ("kind", *_RENT_FIELDS)}
        )
        for field, value in changes.items():
            setattr(prop, field, value)
        return self._detail(self._repository.save(prop), user.currency)

    def archive(self, user_id: str, property_id: str) -> None:
        """Archive a property, as accounts, goals and loans are archived, never hard-deleted.

        The loan link survives: the mortgage still exists and still points here (§16).

        Raises:
            PropertyNotFoundError: no such property, or it belongs to another user.
        """
        prop = self._owned(user_id, property_id)
        prop.archived = True
        self._repository.save(prop)

    def _owned(self, user_id: str, property_id: str) -> Property:
        prop = self._repository.get_for_user(property_id, user_id)
        if prop is None:
            raise PropertyNotFoundError("Property not found.")
        return prop

    def _detail(self, prop: Property, currency: str) -> PropertyDetail:
        return PropertyDetail(
            **to_read(prop, currency).model_dump(),
            linked_mortgages=self._repository.linked_mortgage_ids(prop.id, prop.user_id),
        )

    @staticmethod
    def _check_valued_on(valued_on: date, today: date) -> None:
        if valued_on > today:
            raise PropertyValuationInFutureError(
                "A valuation date must not be in the future.",
                details={"valued_on": valued_on.isoformat(), "today": today.isoformat()},
            )
