"""Business logic for the net-worth synthesis (PROJECT.md §18).

One derived view and no stored money. Assets are account balances plus held property shares;
liabilities are the outstanding principal of active loans. Goals and subscriptions take no part:
a goal labels money already inside an account (§13), and a future charge is not a debt. The held
share and the schedule come from their own features — reused, not recomputed.
"""

from collections.abc import Sequence
from datetime import date

from app.core.months import first_of_month, last_of_month, month_index, month_key
from app.features.accounts.models import Account
from app.features.auth.models import User
from app.features.mortgages.engine import Schedule
from app.features.mortgages.service import ACTIVE, schedule_for
from app.features.networth.repository import NetWorthRepository
from app.features.networth.schemas import (
    CompositionEntry,
    CompositionGroup,
    NetWorthAssets,
    NetWorthLiabilities,
    NetWorthPoint,
    NetWorthSummary,
)
from app.features.properties.service import held_share_minor

#: How many closed months the series looks back over, ending with last month.
SERIES_MONTHS = 12

_BPS_PER_UNIT = 10_000


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
        """The summary as of `today`, with the series over the closed months before it.

        The series is built from month-end figures only: the current month has no snapshot,
        so it is not in the series, and `month_delta_minor` compares the last two closed months.
        """
        accounts = self._repository.accounts(user.id)
        properties = self._repository.properties(user.id)
        schedules = [schedule_for(loan) for loan in self._repository.mortgages(user.id, (ACTIVE,))]

        accounts_minor = sum(account.cached_balance_minor for account in accounts)
        held = [
            (prop.kind, held_share_minor(prop.market_value_minor, prop.ownership_bps))
            for prop in properties
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

        series = self._series(user.id, accounts, properties_minor, schedules, today)
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
        properties_minor: int,
        schedules: Sequence[Schedule],
        today: date,
    ) -> list[NetWorthPoint]:
        """Net worth at each closed month end of the window that holds at least one snapshot.

        A month without any snapshot is omitted rather than zeroed: a zero net worth because
        nothing was imported yet is a false statement. In a month that has one, every account
        counts at its §4 point-in-time balance — nearest snapshot at or before the month end
        plus the rows since, or the opening balance plus the rows when it has no snapshot yet.
        Property values are held flat at their one declared value; loans follow their schedule.
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

        points: list[NetWorthPoint] = []
        for month in range(current - SERIES_MONTHS, current):
            if month not in snapshot_months:
                continue
            month_end = last_of_month(month)
            accounts_minor = sum(
                _balance_at(
                    account,
                    snapshots.get(account.id, {}),
                    row_sums.get(account.id, {}),
                    month,
                )
                for account in accounts
            )
            mortgages_minor = sum(schedule.outstanding_at(month_end) for schedule in schedules)
            points.append(
                NetWorthPoint(
                    month=month_key(month),
                    net_worth_minor=accounts_minor + properties_minor - mortgages_minor,
                )
            )
        return points


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
