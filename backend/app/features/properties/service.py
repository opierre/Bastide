"""Business logic for declared properties: CRUD and the held share.

A property is declared, never observed: the app has no statement to read one from. Net
worth reads it, so the share arithmetic lives here once and no panel keeps its own copy of
a valuation.
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


class PropertyNotFoundError(NotFoundError):
    """Raised when a property doesn't exist or doesn't belong to the caller."""

    code = "PROPERTY_NOT_FOUND"


class PropertyValuationInFutureError(ValidationError):
    """Raised when `valued_on` is ahead of today.

    A valuation dated tomorrow is a typo, and the net-worth series leans on this date to caveat the
    net-worth history — so it is refused rather than carried into a chart as fact.
    """

    code = "PROPERTY_VALUATION_IN_FUTURE"


def held_share_minor(amount_minor: int, ownership_bps: int) -> int:
    """`amount_minor * ownership_bps / 10000`, rounded half-up.

    The only place this arithmetic lives: net-worth assets read the figure, they do not recompute
    it. Integer throughout, as money always is (root `CLAUDE.md`).
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
        # ty: ignore[invalid-argument-type] — the column is plain str; the Literal is enforced by
        # the create/update schemas, which are the only writers of this field.
        kind=prop.kind,
        market_value_minor=prop.market_value_minor,
        valued_on=prop.valued_on,
        ownership_bps=prop.ownership_bps,
        acquisition_price_minor=prop.acquisition_price_minor,
        acquired_on=prop.acquired_on,
        archived=prop.archived,
        currency=currency,
        user_share_value_minor=share,
        acquisition_delta_minor=acquisition_delta,
        created_at=prop.created_at,
        updated_at=prop.updated_at,
    )


class PropertyService:
    """Property CRUD and the derived held share, scoped to a user."""

    def __init__(self, repository: PropertyRepository) -> None:
        self._repository = repository

    def list_for_user(self, user: User, archived: bool = False) -> list[PropertyRead]:
        """The user's properties with their share figures, oldest first.

        Archived ones are absent unless asked for by name with `?archived=true`: they leave
        every aggregate (net-worth assets) but are never destroyed.
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
        """Declare a property. Currency is the user's; no per-property currency exists.

        Raises:
            PropertyValuationInFutureError: `valued_on` is ahead of `today`.
        """
        self._check_valued_on(data.valued_on, today)
        prop = Property(user_id=user.id, archived=False, **data.model_dump())
        return self._detail(self._repository.add(prop), user.currency)

    def update(
        self, user: User, property_id: str, data: PropertyUpdate, today: date
    ) -> PropertyDetail:
        """Patch a property, including archiving and unarchiving through `archived`.

        The patch is validated before anything is assigned, so a rejected edit leaves the
        property exactly as it was. A "nouvelle estimation" is this call carrying
        `market_value_minor` and `valued_on` together (one declared value).

        Raises:
            PropertyNotFoundError: no such property, or it belongs to another user.
            PropertyValuationInFutureError: `valued_on` is ahead of `today`.
        """
        prop = self._owned(user.id, property_id)
        changes: dict[str, Any] = data.model_dump(exclude_none=True)
        if "valued_on" in changes:
            self._check_valued_on(changes["valued_on"], today)
        for field, value in changes.items():
            setattr(prop, field, value)
        return self._detail(self._repository.save(prop), user.currency)

    def archive(self, user_id: str, property_id: str) -> None:
        """Archive a property, as accounts, goals and loans are archived, never hard-deleted.

        The loan link survives: the mortgage still exists and still points here.

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
