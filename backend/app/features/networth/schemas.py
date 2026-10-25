"""Schemas for the net-worth summary and the month-end totals a user declares.

Every summary figure is derived; only a declared total is stored, and it is the user's own.
"""

from datetime import date
from typing import Literal

from pydantic import BaseModel

CompositionGroup = Literal["account", "property"]
#: Where a series point's account total comes from: the imported ledger, or a figure the user
#: declared for a month the ledger does not cover.
PointSource = Literal["ledger", "declared"]


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
    source: PointSource


class NetWorthSummary(BaseModel):
    """`GET /networth/summary`: what the user owns, what they owe, and the month-end history."""

    assets: NetWorthAssets
    liabilities: NetWorthLiabilities
    net_worth_minor: int
    composition: list[CompositionEntry]
    month_delta_minor: int | None
    series: list[NetWorthPoint]
    property_values_held_flat: bool
    valued_on_oldest: date | None
    currency: str


class DeclaredBalanceWrite(BaseModel):
    """`PUT /networth/declared/{month}`: what every account held together at that month end."""

    amount_minor: int


class DeclaredBalanceRead(BaseModel):
    """One declared month-end total.

    `superseded` is true when the ledger has a snapshot for that month: the series then draws
    the imported figure, and this one is kept but not shown on the chart.
    """

    month: str
    amount_minor: int
    currency: str
    superseded: bool
