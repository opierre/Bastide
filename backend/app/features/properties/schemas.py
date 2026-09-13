"""Pydantic I/O for declared properties and the share figures derived from them."""

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

#: The four natures a declared property can take (§4c). A label everywhere but in §16, where
#: `primary_residence` alone carries the IFI abattement.
PropertyKind = Literal["primary_residence", "rental", "secondary", "other"]

#: How rent is taxed (§16); null when the property is not rented.
PropertyRegime = Literal["micro_foncier", "reel"]


class PropertyCreate(BaseModel):
    """Payload declaring a property.

    `currency` is absent: it is the user's, per the Phase 1 one-currency rule (multi-currency
    skill), and the share figures are absent because nothing derived is stored.
    """

    model_config = ConfigDict(extra="forbid")

    label: str = Field(min_length=1, max_length=255)
    kind: PropertyKind
    market_value_minor: int = Field(gt=0)
    valued_on: date
    ownership_bps: int = Field(default=10_000, ge=1, le=10_000)
    acquisition_price_minor: int | None = Field(default=None, ge=0)
    acquired_on: date | None = None
    annual_rent_minor: int | None = Field(default=None, ge=0)
    annual_charges_minor: int | None = Field(default=None, ge=0)
    property_regime: PropertyRegime | None = None


class PropertyUpdate(BaseModel):
    """Patch payload for a property.

    Omitted fields are left alone; `None` is indistinguishable from absent, as everywhere else
    in this API, so clearing a rent field or an acquisition price is not expressible here.

    « Nouvelle estimation » is this payload carrying `market_value_minor` and `valued_on`
    together: a property has exactly one declared value (§4c), so a re-valuation replaces it
    rather than appending to a history that does not exist.
    """

    model_config = ConfigDict(extra="forbid")

    label: str | None = Field(default=None, min_length=1, max_length=255)
    kind: PropertyKind | None = None
    market_value_minor: int | None = Field(default=None, gt=0)
    valued_on: date | None = None
    ownership_bps: int | None = Field(default=None, ge=1, le=10_000)
    acquisition_price_minor: int | None = Field(default=None, ge=0)
    acquired_on: date | None = None
    annual_rent_minor: int | None = Field(default=None, ge=0)
    annual_charges_minor: int | None = Field(default=None, ge=0)
    property_regime: PropertyRegime | None = None
    #: Archiving is also reachable through `DELETE`; `false` here is how a bien is unarchived.
    archived: bool | None = None


class PropertyRead(BaseModel):
    """A declared property with the two figures every card prints (`15-synthese.md` §Biens)."""

    id: str
    label: str
    kind: PropertyKind
    market_value_minor: int
    valued_on: date
    ownership_bps: int
    acquisition_price_minor: int | None
    acquired_on: date | None
    annual_rent_minor: int | None
    annual_charges_minor: int | None
    property_regime: PropertyRegime | None
    archived: bool
    currency: str
    #: The held share of the declared value; derived here and nowhere else.
    user_share_value_minor: int
    #: The held share less the held share of the acquisition price; null without a price.
    acquisition_delta_minor: int | None
    created_at: datetime
    updated_at: datetime


class PropertyDetail(PropertyRead):
    """A property with the loans pointing at it, so the user sees the link they made (§16)."""

    #: Ids of the caller's mortgages whose `property_id` is this property, oldest first.
    linked_mortgages: list[str]
