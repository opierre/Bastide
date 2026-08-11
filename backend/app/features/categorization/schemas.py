"""Schemas for stage-2 categorisation: what the model suggested, and what we do about it."""

from typing import Literal

from pydantic import BaseModel, Field

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
