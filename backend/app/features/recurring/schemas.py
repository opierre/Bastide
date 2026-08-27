"""Pydantic I/O for the recurring feature, and the vocabularies the column values come from."""

from typing import Literal

from pydantic import BaseModel

#: Every value `recurring_series.cadence` may carry. `irregular` exists for user-declared series
#: only: the detector emits a series when it recognises a rhythm and nothing otherwise, so it
#: never produces one (`PROJECT.md` §12).
Cadence = Literal["weekly", "monthly", "quarterly", "yearly", "irregular"]

#: The subset detection can conclude — the four bands a median gap is classified into.
DetectedCadence = Literal["weekly", "monthly", "quarterly", "yearly"]

#: Lifecycle of a series. `dismissed` and `cancelled` are the user's word on it, which is why
#: re-detection leaves both alone.
SeriesStatus = Literal["detected", "confirmed", "dismissed", "cancelled"]


class DetectRequest(BaseModel):
    """Ask for a detection pass, over one account or over all of them."""

    account_id: str | None = None


class DetectionResultRead(BaseModel):
    """What a detection pass did. Series it deliberately left alone count in neither number."""

    created_count: int
    updated_count: int
