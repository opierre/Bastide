"""Request/response schemas for the rules feature."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.features.transactions.schemas import TransactionRead

MatchField = Literal["description_clean", "merchant", "amount"]
MatchType = Literal["contains", "equals", "regex", "range"]


class RuleCreate(BaseModel):
    """Payload to create a categorization rule."""

    priority: int
    match_field: MatchField
    match_type: MatchType
    pattern: str = Field(min_length=1, max_length=255)
    category_id: str
    enabled: bool = True


class RuleUpdate(BaseModel):
    """Patch payload for a rule."""

    priority: int | None = None
    match_field: MatchField | None = None
    match_type: MatchType | None = None
    pattern: str | None = Field(default=None, min_length=1, max_length=255)
    category_id: str | None = None
    enabled: bool | None = None


class RuleRead(BaseModel):
    """A categorization rule as returned by the API."""

    id: str
    priority: int
    match_field: str
    match_type: str
    pattern: str
    category_id: str
    enabled: bool
    created_at: datetime


class RuleApplyRequest(BaseModel):
    """Payload for re-running the rule engine; ``account_id`` narrows it to one account."""

    account_id: str | None = None


class RuleApplyResult(BaseModel):
    """Result of a rule apply run."""

    recategorized_count: int


class RulePreviewRequest(BaseModel):
    """An unsaved rule condition to count against the caller's existing transactions."""

    match_field: MatchField
    match_type: MatchType
    pattern: str = Field(min_length=1, max_length=255)
    account_id: str | None = None


class RulePreviewResult(BaseModel):
    """How many transactions a condition matches, with a few of them to show as examples."""

    match_count: int
    samples: list[TransactionRead]
