"""Request/response schemas for the accounts feature."""

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field

# `deferred_card` is the holding account a deferred-debit card gets: French banks
# post card purchases to it during the month and settle the total against the
# current account on one date. It is a real balance the user watches, so it is an
# account type rather than a flag on `credit`.
AccountType = Literal["checking", "savings", "credit", "deferred_card", "cash", "other"]


class AccountCreate(BaseModel):
    """Payload to open a new account."""

    name: str = Field(min_length=1, max_length=255)
    type: AccountType
    institution: str = Field(min_length=1, max_length=255)
    opening_balance_minor: int
    ofx_account_id: str | None = Field(
        default=None,
        max_length=255,
        description="The bank's own account id (OFX `ACCTID`). Optional, unique per user.",
    )
    currency: str | None = Field(
        default=None,
        min_length=3,
        max_length=3,
        pattern=r"^[A-Za-z]{3}$",
        description=(
            "ISO 4217 code the account is denominated in. Omit — the normal case — and it "
            "defaults to the user's. Sent only when the source *declares* one, i.e. an OFX "
            "statement's `CURDEF`: the file states which currency its figures are in, and "
            "the account holding them has to agree or every balance it shows is mislabelled."
        ),
    )
    settlement_account_id: str | None = Field(
        default=None,
        description=(
            "Deferred cards only, and required for one: the account the card's monthly debit "
            "is drawn from. Must be another of the user's accounts, not itself a card."
        ),
    )


class AccountUpdate(BaseModel):
    """Patch payload: name, type, institution, the bank's account id, and the opening
    balance are mutable.

    `ofx_account_id` is patchable so an account created before its first import can be
    bound to the id its statements carry. `opening_balance_minor` is a manual correction —
    imports derive it automatically from a statement's first `LEDGERBAL` where possible,
    but a statement without a `LEDGERBAL` never gives one, so this is the escape hatch
    for that account (and for fixing a bad derivation).
    """

    name: str | None = Field(default=None, min_length=1, max_length=255)
    type: AccountType | None = None
    institution: str | None = Field(default=None, min_length=1, max_length=255)
    ofx_account_id: str | None = Field(default=None, max_length=255)
    opening_balance_minor: int | None = None
    settlement_account_id: str | None = Field(
        default=None,
        description=(
            "Deferred cards only: the account the card's monthly debit is drawn from, or "
            "null to clear it. Must be another of the user's accounts, not itself a card."
        ),
    )


class AccountRead(BaseModel):
    """An account as returned by the API, including its derived current balance."""

    id: str
    name: str
    type: str
    institution: str
    currency: str
    ofx_account_id: str | None
    settlement_account_id: str | None
    opening_balance_minor: int
    balance_minor: int
    archived: bool
    created_at: datetime
    updated_at: datetime


SettlementMatchType = Literal["contains", "equals", "regex"]


class SettlementRuleRead(BaseModel):
    """A deferred card's settlement rule: what in a debit's label says it pays this card."""

    id: str
    match_type: str
    pattern: str
    enabled: bool


class SettlementRuleState(BaseModel):
    """A card's settlement rule, if it has one, and the pattern proposed for it."""

    rule: SettlementRuleRead | None
    suggested_pattern: str | None = Field(
        description=(
            "Read from the labels of the account that pays the card: the fragment naming the "
            "card that recurs month after month. Null when the card's number is unknown."
        )
    )


class SettlementRuleWrite(BaseModel):
    """Create or replace a card's settlement rule. It matches the cleaned label."""

    match_type: SettlementMatchType = "contains"
    pattern: str = Field(min_length=1, max_length=255)


class SettlementRuleSaved(BaseModel):
    """The saved rule, and how many already-imported rows it filed as a settlement."""

    rule: SettlementRuleRead
    recategorized_count: int


CardSettlementIssueKind = Literal["no_settlement_account", "no_rule", "unsettled"]


class CardSettlementIssue(BaseModel):
    """What keeps one deferred card's purchases from counting exactly once.

    The first missing step only: a card with no settlement account is not also told it lacks
    a rule.
    """

    account_id: str
    issue: CardSettlementIssueKind
    #: `unsettled` only: the card's purchases since its last settlement that its paying account,
    #: imported well past them, shows no settlement for — the rule no longer matches the bank's
    #: wording, most likely. Their total, signed (negative), how many, and the oldest's date.
    amount_minor: int | None = None
    count: int | None = None
    since: date | None = None


class CardSettlementStatus(BaseModel):
    """Every deferred card that needs the user's attention; empty when all count once."""

    cards: list[CardSettlementIssue]
