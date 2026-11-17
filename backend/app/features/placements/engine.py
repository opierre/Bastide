"""Pure arithmetic for placements: the envelope catalogue and every figure derived on read.

No database, no FastAPI: the service and the net-worth series both call into here, so a
placement's value at a date is defined once. Money is signed integer minor units throughout.
"""

from calendar import monthrange
from dataclasses import dataclass
from datetime import date

from app.core.months import MONTHS_PER_YEAR

_BPS_PER_UNIT = 10_000

#: A declared value older than this many months is flagged stale (`17-placements.md` §States).
STALE_AFTER_MONTHS = 4

#: The currency the catalogue's ceilings are written in. A user in another currency sees no
#: ceiling rather than a euro figure misread as theirs (multi-currency skill: no conversion).
CEILING_CURRENCY = "EUR"


@dataclass(frozen=True, slots=True)
class EnvelopeRule:
    """What the panel reads off an envelope: an indicative payment ceiling and age milestone.

    Indicative readings of French rules, not advice; the panel says so.
    """

    payment_ceiling_minor: int | None
    milestone_years: int | None


#: The envelope catalogue, in the order the « Enveloppe » select lists it.
ENVELOPES: dict[str, EnvelopeRule] = {
    "pea": EnvelopeRule(payment_ceiling_minor=15_000_000, milestone_years=5),
    # Combined with a PEA; the figure shown is the joint ceiling.
    "pea_pme": EnvelopeRule(payment_ceiling_minor=22_500_000, milestone_years=5),
    "life_insurance": EnvelopeRule(payment_ceiling_minor=None, milestone_years=8),
    "per": EnvelopeRule(payment_ceiling_minor=None, milestone_years=None),
    "pee": EnvelopeRule(payment_ceiling_minor=None, milestone_years=5),
    "securities_account": EnvelopeRule(payment_ceiling_minor=None, milestone_years=None),
    "other": EnvelopeRule(payment_ceiling_minor=None, milestone_years=None),
}


def ceiling_for(envelope: str, currency: str) -> int | None:
    """The envelope's payment ceiling, or `None` when it has none or the user is not in euros."""
    if currency.upper() != CEILING_CURRENCY:
        return None
    return ENVELOPES[envelope].payment_ceiling_minor


def add_months(day: date, months: int) -> date:
    """`day` moved by `months` calendar months, clamped to the target month's last day."""
    index = day.year * MONTHS_PER_YEAR + day.month - 1 + months
    year, month = divmod(index, MONTHS_PER_YEAR)
    return date(year, month + 1, min(day.day, monthrange(year, month + 1)[1]))


def full_months_between(start: date, end: date) -> int:
    """Whole calendar months from `start` to `end`; 0 when `end` is not after `start`."""
    months = (end.year - start.year) * MONTHS_PER_YEAR + end.month - start.month
    if end.day < start.day:
        months -= 1
    return max(months, 0)


def ratio_bps(numerator: int, denominator: int) -> int | None:
    """`numerator / denominator` in basis points, rounded half away from zero.

    `None` when the denominator is not positive: a gain as a share of nothing paid in (or of
    more withdrawn than paid in) means nothing.
    """
    if denominator <= 0:
        return None
    magnitude = (2 * abs(numerator) * _BPS_PER_UNIT + denominator) // (2 * denominator)
    return magnitude if numerator >= 0 else -magnitude


@dataclass(frozen=True, slots=True)
class Holding:
    """One placement's dated history, enough to value it at any date.

    `movements` and `valuations` are `(date, amount_minor)` pairs, in any order.
    """

    envelope: str
    opened_on: date
    closed_on: date | None
    movements: tuple[tuple[date, int], ...]
    valuations: tuple[tuple[date, int], ...]

    def net_payments_on(self, day: date) -> int:
        """Paid in less withdrawn, counting the movements dated on or before `day`."""
        return sum(amount for occurred_on, amount in self.movements if occurred_on <= day)

    def last_valuation_on(self, day: date) -> tuple[date, int] | None:
        """The latest declared value dated on or before `day`, or `None`."""
        return max((v for v in self.valuations if v[0] <= day), default=None)

    def is_held_on(self, day: date) -> bool:
        """Opened on or before `day` and not closed by then (it leaves from its closing date)."""
        return self.opened_on <= day and (self.closed_on is None or day < self.closed_on)

    def value_on(self, day: date) -> int:
        """What the placement counts for in net worth on `day`.

        Its last declared value on or before that date, held flat until the next one; before
        the first declaration, its net payments. Zero before opening and from its closing date.
        """
        if not self.is_held_on(day):
            return 0
        last = self.last_valuation_on(day)
        return last[1] if last is not None else self.net_payments_on(day)
