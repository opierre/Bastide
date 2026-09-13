"""Calendar-month arithmetic on a single integer index, shared by every month-bucketed figure.

A month index is ``year * 12 + month - 1``: consecutive months are consecutive integers, so a
window of months is a ``range`` and "twelve months back" is a subtraction.
"""

from calendar import monthrange
from datetime import date

MONTHS_PER_YEAR = 12


def month_index(day: date) -> int:
    """The index of the month ``day`` falls in."""
    return day.year * MONTHS_PER_YEAR + day.month - 1


def month_key(index: int) -> str:
    """`YYYY-MM` for a month index."""
    return f"{index // MONTHS_PER_YEAR:04d}-{index % MONTHS_PER_YEAR + 1:02d}"


def first_of_month(index: int) -> date:
    """The first day of a month index."""
    return date(index // MONTHS_PER_YEAR, index % MONTHS_PER_YEAR + 1, 1)


def last_of_month(index: int) -> date:
    """The last day of a month index."""
    year, month = index // MONTHS_PER_YEAR, index % MONTHS_PER_YEAR + 1
    return date(year, month, monthrange(year, month)[1])
