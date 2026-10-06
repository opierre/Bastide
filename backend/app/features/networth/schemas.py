"""Response schemas for the net-worth summary. Every figure is derived; none is stored."""

from datetime import date
from typing import Literal

from pydantic import BaseModel

CompositionGroup = Literal["account", "property"]


class NetWorthAssets(BaseModel):
    """The asset side: derived account balances and held property shares."""

    accounts_minor: int
    properties_minor: int


class NetWorthLiabilities(BaseModel):
    """The liability side: outstanding principal of active loans only."""

    mortgages_minor: int


class CompositionEntry(BaseModel):
    """One slice of the asset strip: an account type or a property kind.

    `key` is the account `type` or the property `kind`, labelled from ARB by the frontend.
    `share_bps` is of total assets; the entries' shares sum to exactly 10000 when assets are
    positive, and are all 0 otherwise.
    """

    group: CompositionGroup
    key: str
    amount_minor: int
    share_bps: int


class NetWorthPoint(BaseModel):
    """Net worth at the end of one closed month (`YYYY-MM`)."""

    month: str
    net_worth_minor: int


class NetWorthSummary(BaseModel):
    """`GET /networth/summary`: what the user owns, what they owe, and the recent history."""

    assets: NetWorthAssets
    liabilities: NetWorthLiabilities
    net_worth_minor: int
    composition: list[CompositionEntry]
    month_delta_minor: int | None
    series: list[NetWorthPoint]
    property_values_held_flat: bool
    valued_on_oldest: date | None
    currency: str
