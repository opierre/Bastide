"""The vocabularies the recurring columns draw their values from."""

from typing import Literal

#: Every value `recurring_series.cadence` may carry. `irregular` exists for user-declared series
#: only: the detector emits a series when it recognises a rhythm and nothing otherwise, so it
#: never produces one (`PROJECT.md` §12).
Cadence = Literal["weekly", "monthly", "quarterly", "yearly", "irregular"]

#: The subset detection can conclude — the four bands a median gap is classified into.
DetectedCadence = Literal["weekly", "monthly", "quarterly", "yearly"]

#: Lifecycle of a series. `dismissed` and `cancelled` are the user's word on it, which is why
#: re-detection leaves both alone.
SeriesStatus = Literal["detected", "confirmed", "dismissed", "cancelled"]

