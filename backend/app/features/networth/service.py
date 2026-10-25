"""Business logic for the net-worth synthesis.

One derived view, and one kind of stored money: the month-end totals a user declares for the
time before their first import. Assets are account balances plus held property shares;
liabilities are the outstanding principal of active loans. Goals and subscriptions take no part:
a goal labels money already inside an account, and a future charge is not a debt. The held
share and the schedule come from their own features — reused, not recomputed.
"""

from collections.abc import Sequence
from datetime import date

from app.core.errors import NotFoundError, ValidationError
from app.core.months import (
    MONTHS_PER_YEAR,
    first_of_month,
    last_of_month,
    month_index,
    month_key,
)
from app.features.accounts.models import Account
from app.features.auth.models import User
from app.features.mortgages.engine import Schedule
from app.features.mortgages.service import ACTIVE, schedule_for
from app.features.networth.models import DeclaredBalance
from app.features.networth.repository import NetWorthRepository
from app.features.networth.schemas import (
    CompositionEntry,
    CompositionGroup,
    DeclaredBalanceRead,
    NetWorthAssets,
    NetWorthLiabilities,
    NetWorthPoint,
    NetWorthSummary,
    PointSource,
)
from app.features.properties.service import held_share_minor

_BPS_PER_UNIT = 10_000


class DeclaredMonthNotClosedError(ValidationError):
    """Raised when a total is declared for the current month or a later one.

    The series holds closed months only, and a month still running has no end-of-month figure
    yet: such a total could never be drawn, so it is refused rather than stored.
    """

    code = "DECLARED_MONTH_NOT_CLOSED"


class DeclaredBalanceNotFoundError(NotFoundError):
    """Raised when the caller has no declared total for that month."""

    code = "DECLARED_BALANCE_NOT_FOUND"


def parse_month(key: str) -> int:
    """The month index of a `YYYY-MM` key; the route has already checked its shape."""
    year, month = key.split("-")
    return int(year) * MONTHS_PER_YEAR + int(month) - 1


def shares_bps(amounts: Sequence[int]) -> list[int]:
    """Each amount's share of their sum in bps, summing to exactly 10000 by largest remainder.

    Amounts are signed (a credit account is negative), so a share can be too. With a sum that
    is not positive, a percentage of it means nothing and every share is 0.
    """
    total = sum(amounts)
    if total <= 0:
        return [0] * len(amounts)
    floors = [amount * _BPS_PER_UNIT // total for amount in amounts]
    remainders = [
        amount * _BPS_PER_UNIT - floor * total
        for amount, floor in zip(amounts, floors, strict=True)
    ]
    shortfall = _BPS_PER_UNIT - sum(floors)
    # Ties go to the earlier entry, so the result is deterministic for a given order.
    for position in sorted(range(len(amounts)), key=lambda i: -remainders[i])[:shortfall]:
        floors[position] += 1
    return floors


class NetWorthService:
    """Derives the net-worth summary for one user, per request."""

    def __init__(self, repository: NetWorthRepository) -> None:
        self._repository = repository

    def summary(self, user: User, today: date) -> NetWorthSummary:
        """The summary as of `today`, with the series over every closed month before it.

        The series is built from month-end figures only: the current month has no snapshot,
        so it is not in the series, and `month_delta_minor` compares the last two closed months.
        """
        accounts = self._repository.accounts(user.id)
        properties = self._repository.properties(user.id)
        loans = [
            (loan.first_payment_date, schedule_for(loan))
            for loan in self._repository.mortgages(user.id, (ACTIVE,))
        ]
        schedules = [schedule for _, schedule in loans]

        accounts_minor = sum(account.cached_balance_minor for account in accounts)
        held = [
            (prop.kind, held_share_minor(prop.market_value_minor, prop.ownership_bps))
            for prop in properties
        ]
        holdings = [
            (prop.acquired_on, share) for prop, (_, share) in zip(properties, held, strict=True)
        ]
        properties_minor = sum(share for _, share in held)
        mortgages_minor = sum(schedule.outstanding_at(today) for schedule in schedules)

        by_type: dict[str, int] = {}
        for account in accounts:
            by_type[account.type] = by_type.get(account.type, 0) + account.cached_balance_minor
        by_kind: dict[str, int] = {}
        for kind, share in held:
            by_kind[kind] = by_kind.get(kind, 0) + share
        slices: list[tuple[CompositionGroup, str, int]] = [
            ("account", key, amount) for key, amount in by_type.items()
        ] + [("property", key, amount) for key, amount in by_kind.items()]
        composition = [
            CompositionEntry(group=group, key=key, amount_minor=amount, share_bps=share)
            for (group, key, amount), share in zip(
                slices, shares_bps([amount for _, _, amount in slices]), strict=True
            )
        ]

        series = self._series(user.id, accounts, holdings, loans, today)
        return NetWorthSummary(
            assets=NetWorthAssets(accounts_minor=accounts_minor, properties_minor=properties_minor),
            liabilities=NetWorthLiabilities(mortgages_minor=mortgages_minor),
            net_worth_minor=accounts_minor + properties_minor - mortgages_minor,
            composition=composition,
            month_delta_minor=(
                series[-1].net_worth_minor - series[-2].net_worth_minor
                if len(series) >= 2
                else None
            ),
            series=series,
            property_values_held_flat=bool(properties),
            valued_on_oldest=min((prop.valued_on for prop in properties), default=None),
            currency=user.currency,
        )

    def _series(
        self,
        user_id: str,
        accounts: Sequence[Account],
        holdings: Sequence[tuple[date | None, int]],
        loans: Sequence[tuple[date, Schedule]],
        today: date,
    ) -> list[NetWorthPoint]:
        """Net worth at each closed month end that has a snapshot or a declared total.

        The series runs from the oldest such month to last month; the panel picks the range it
        shows. A month with neither is omitted rather than zeroed: a zero net worth because
        nothing was imported yet is a false statement. In a month with a snapshot, every account
        counts at its point-in-time balance — nearest snapshot at or before the month end
        plus the rows since, or the opening balance plus the rows when it has no snapshot yet.
        A month without one takes the user's declared total in place of the accounts: the
        ledger, when it has the month, always wins, and the two are never added up.
        Property values are held flat at their one declared value; loans follow their schedule.

        `holdings` are `(acquired_on, held share)` and `loans` are `(first payment date,
        schedule)`. Neither counts before it existed: a property enters at its acquisition
        month, a loan the month before its first payment — when it is paid out, the date the
        app does not record. Counting both all along would add the down payment twice before
        the purchase: once as the cash still in the accounts, once inside property − loan.
        A property without an acquisition date counts all along, as there is no date to start at.
        """
        current = month_index(today)
        window_end = first_of_month(current)
        account_ids = [account.id for account in accounts]
        snapshots: dict[str, dict[int, int]] = {}
        for account_id, period_end, balance in self._repository.snapshots(
            user_id, account_ids, window_end
        ):
            snapshots.setdefault(account_id, {})[month_index(period_end)] = balance
        row_sums = self._repository.monthly_row_sums(user_id, account_ids, window_end)
        snapshot_months = {month for months in snapshots.values() for month in months}
        declared = {
            month_index(row.period_end): row.amount_minor
            for row in self._repository.declared(user_id, window_end)
        }
        data_months = snapshot_months | declared.keys()
        if not data_months:
            return []

        points: list[NetWorthPoint] = []
        for month in range(min(data_months), current):
            source: PointSource
            if month in snapshot_months:
                source = "ledger"
                accounts_minor = sum(
                    _balance_at(
                        account,
                        snapshots.get(account.id, {}),
                        row_sums.get(account.id, {}),
                        month,
                    )
                    for account in accounts
                )
            elif month in declared:
                source = "declared"
                accounts_minor = declared[month]
            else:
                continue
            month_end = last_of_month(month)
            properties_minor = sum(
                share
                for acquired_on, share in holdings
                if acquired_on is None or acquired_on <= month_end
            )
            mortgages_minor = sum(
                schedule.outstanding_at(month_end)
                for first_payment, schedule in loans
                if month >= month_index(first_payment) - 1
            )
            points.append(
                NetWorthPoint(
                    month=month_key(month),
                    net_worth_minor=accounts_minor + properties_minor - mortgages_minor,
                    source=source,
                )
            )
        return points

    def declared(self, user: User) -> list[DeclaredBalanceRead]:
        """The user's declared totals, oldest first, each flagged when the ledger covers it."""
        ledger = self._repository.snapshot_month_ends(user.id)
        return [
            _declared_read(row, row.period_end in ledger)
            for row in self._repository.declared(user.id)
        ]

    def declare(
        self, user: User, month: str, amount_minor: int, today: date
    ) -> DeclaredBalanceRead:
        """Record, or replace, the total all accounts held at the end of `month`.

        Raises:
            DeclaredMonthNotClosedError: `month` is the current month or a later one.
        """
        index = parse_month(month)
        if index >= month_index(today):
            raise DeclaredMonthNotClosedError(
                "A balance can only be declared for a month that has ended.",
                details={"month": month},
            )
        period_end = last_of_month(index)
        row = self._repository.declared_at(user.id, period_end) or DeclaredBalance(
            user_id=user.id, period_end=period_end
        )
        row.amount_minor = amount_minor
        row.currency = user.currency
        row = self._repository.save_declared(row)
        return _declared_read(row, period_end in self._repository.snapshot_month_ends(user.id))

    def remove_declared(self, user: User, month: str) -> None:
        """Delete the user's declared total for `month`.

        Raises:
            DeclaredBalanceNotFoundError: there is none for that month.
        """
        row = self._repository.declared_at(user.id, last_of_month(parse_month(month)))
        if row is None:
            raise DeclaredBalanceNotFoundError(
                "No balance is declared for that month.", details={"month": month}
            )
        self._repository.delete_declared(row)


def _declared_read(row: DeclaredBalance, superseded: bool) -> DeclaredBalanceRead:
    return DeclaredBalanceRead(
        month=month_key(month_index(row.period_end)),
        amount_minor=row.amount_minor,
        currency=row.currency,
        superseded=superseded,
    )


def _balance_at(
    account: Account,
    snapshots: dict[int, int],
    row_sums: dict[int, int],
    month: int,
) -> int:
    """The account's balance at the end of `month`, from its nearest snapshot plus rows since.

    `snapshots` and `row_sums` are this account's own, keyed by month index. Snapshots are
    month-end figures, so "rows since" are the rows of the following months.
    """
    earlier = [index for index in snapshots if index <= month]
    if earlier:
        since = max(earlier)
        base = snapshots[since]
    else:
        since = None
        base = account.opening_balance_minor
    return base + sum(
        total
        for index, total in row_sums.items()
        if index <= month and (since is None or index > since)
    )
