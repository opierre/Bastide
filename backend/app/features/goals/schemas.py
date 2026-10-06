"""Pydantic I/O for savings goals and their allocation ledger."""

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

#: Every value `goals.status` may carry. `reached` is *derived* — it is settled from the
#: allocation sum, never asserted by a client (see `GoalStatusPatch`).
GoalStatus = Literal["active", "reached", "archived"]

#: The statuses a client may ask for. Archiving and restoring are the user's two decisions
#: about a goal (`PROJECT.md` §13); whether a restored goal lands on `active` or `reached` is
#: the backend's arithmetic, so `reached` is not something a payload may claim.
GoalStatusPatch = Literal["active", "archived"]


class GoalCreate(BaseModel):
    """Payload creating a savings goal.

    `extra="forbid"` is what rejects an `account_id`: a goal is not linked to an account
    (`PROJECT.md` §13), and silently dropping the field would let a client believe it had
    stored something. `currency` is absent for the same reason it is absent from every other
    payload — it is the user's, not a per-row choice (multi-currency skill).
    """

    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=255)
    #: A target is an amount to reach, so positive — the money sign convention (`PROJECT.md`
    #: §8) applies to movements, and a goal is not one.
    target_minor: int = Field(gt=0)
    target_date: date | None = None
    icon: str = Field(min_length=1, max_length=50)
    color: str = Field(min_length=1, max_length=20)


class GoalUpdate(BaseModel):
    """Patch payload for a goal.

    Omitted fields are left alone; `None` is indistinguishable from absent, as everywhere else
    in this API, so clearing a target date is not expressible here.
    """

    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=1, max_length=255)
    target_minor: int | None = Field(default=None, gt=0)
    target_date: date | None = None
    icon: str | None = Field(default=None, min_length=1, max_length=50)
    color: str | None = Field(default=None, min_length=1, max_length=20)
    status: GoalStatusPatch | None = None


class GoalRead(BaseModel):
    """A goal as returned by the API, with its progress derived from the allocation ledger."""

    id: str
    name: str
    target_minor: int
    currency: str
    target_date: date | None
    icon: str
    color: str
    status: GoalStatus
    #: The signed sum of the goal's allocations, so it falls again when money is taken back out.
    progress_minor: int
    #: `progress_minor / target_minor`, **unclamped**: an over-funded goal reports past 1.0 and
    #: the UI decides what to draw (`PROJECT.md` §13). A ratio, never a money value.
    progress_pct: float
    created_at: datetime
    updated_at: datetime


class AllocationCreate(BaseModel):
    """Payload adding one line to a goal's ledger.

    `amount_minor` is signed: negative takes money back out of the envelope. There is no
    separate withdrawal endpoint, and no PATCH — a mistake is corrected with an offsetting
    line, which is what an honest ledger looks like.
    """

    model_config = ConfigDict(extra="forbid")

    amount_minor: int
    allocated_on: date
    note: str | None = None


class AllocationRead(BaseModel):
    """One allocation as returned by the API."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    goal_id: str
    amount_minor: int
    allocated_on: date
    note: str | None
    created_at: datetime
