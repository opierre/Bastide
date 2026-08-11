"""Schemas for stage-2 categorisation: what the model suggested, and what we do about it."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

#: What the decision layer concluded for one row. ``assigned`` carries a category and a
#: confidence at or above the user's threshold; ``deferred`` carries neither and sends the row
#: to the review queue; ``failed`` means the runtime itself errored for that row's batch.
OutcomeStatus = Literal["assigned", "deferred", "failed"]


class Suggestion(BaseModel):
    """One well-formed suggestion parsed out of the model's reply.

    Existence of a ``Suggestion`` says only that the reply was *shaped* correctly and named a
    category actually on offer — it says nothing about whether the confidence clears the
    threshold. That judgement belongs to the service.
    """

    index: int = Field(ge=0)
    category_id: str = Field(min_length=1)
    confidence: float = Field(ge=0.0, le=1.0)


class SuggestionOutcome(BaseModel):
    """The decision for one row of a batch, correlated with the input by ``index``.

    ``category_id`` is set only when ``status == "assigned"``: a below-threshold guess is not a
    weak assignment, it is no assignment at all (`PROJECT.md` §7). ``confidence`` is kept even
    when deferring, because it is useful to order the review queue by how close the model got.
    """

    index: int = Field(ge=0)
    status: OutcomeStatus
    category_id: str | None = None
    confidence: float | None = None
    #: Mirrors what the transaction row will carry; always the inverse of an assignment.
    needs_review: bool


#: Which rows a run reconsiders. ``pending`` takes only what nothing has categorised yet;
#: ``all`` additionally takes rows a previous run assigned, so a changed model or threshold
#: can be applied to them. Neither ever includes a `user` or `rule` row (`PROJECT.md` §7).
RunScope = Literal["pending", "all"]

#: What started the run: the user asking for one, or an import finishing.
RunTrigger = Literal["import", "manual"]

#: ``pending``/``running`` are the in-flight pair the one-run-at-a-time check looks for; the
#: other four are terminal. ``partial`` means some rows failed, ``failed`` that the run got
#: nowhere at all.
RunStatus = Literal["pending", "running", "success", "partial", "failed", "cancelled"]


class RunCreate(BaseModel):
    """Request to start a categorisation run."""

    account_id: str | None = None
    scope: RunScope


class CategorizationRunRead(BaseModel):
    """A run as the API returns it — polled for progress while it is in flight."""

    # `model_tag` is the runtime's model identifier, not a Pydantic model attribute.
    model_config = ConfigDict(from_attributes=True, protected_namespaces=())

    id: str
    account_id: str | None
    import_batch_id: str | None
    trigger: RunTrigger
    status: RunStatus
    model_tag: str | None
    total_count: int
    processed_count: int
    assigned_count: int
    deferred_count: int
    failed_count: int
    error_message: str | None
    started_at: datetime | None
    finished_at: datetime | None
    created_at: datetime
