"""The account detail page's figures: balance history, period stats, and card settlement.

Each is derived from the ledger on request. The history is one point per month — the page
draws month-ends, not daily wiggle — summed in one grouped query rather than a balance lookup
per month.
"""

import calendar
from collections.abc import Sequence
from datetime import date, datetime, timedelta

from sqlalchemy import extract, func, select
from sqlalchemy.orm import Session

from app.features.accounts.models import Account
from app.features.accounts.schemas import (
    AccountOverview,
    AccountRead,
    BalancePoint,
    CardSettlement,
    LinkedCard,
    PeriodStats,
    SettlementCycle,
    SettlementRuleRead,
)
from app.features.accounts.settlement_rule import SettlementRuleService, card_digits
from app.features.imports.models import ImportBatch
from app.features.rules.engine import matches
from app.features.rules.models import CategorizationRule
from app.features.transactions.models import Transaction

#: The page's stats window, in months.
PERIOD_MONTHS = 12


def add_months(day: date, months: int) -> date:
    """``day`` moved by whole months, its day clamped to the target month's length."""
    index = day.year * 12 + day.month - 1 + months
    year, month = divmod(index, 12)
    month += 1
    return date(year, month, min(day.day, calendar.monthrange(year, month)[1]))


def month_end(day: date) -> date:
    """The last day of ``day``'s month."""
    return day.replace(day=calendar.monthrange(day.year, day.month)[1])


def balance_history(
    opening_minor: int, monthly_sums: dict[tuple[int, int], int], today: date
) -> list[BalancePoint]:
    """Month-end balances from the first month with a row to today's month.

    Each is the opening balance plus every row up to that month's end; the current month's
    point stands at today. Empty without any row.
    """
    if not monthly_sums:
        return []
    year, month = min(monthly_sums)
    cursor = date(year, month, 1)
    balance = opening_minor
    points: list[BalancePoint] = []
    while cursor <= today:
        balance += monthly_sums.get((cursor.year, cursor.month), 0)
        points.append(BalancePoint(as_of=min(month_end(cursor), today), balance_minor=balance))
        cursor = add_months(cursor, 1)
    return points


def consecutive_rises(points: Sequence[BalancePoint]) -> int:
    """How many points in a row, ending with the last, closed above the one before."""
    rises = 0
    for previous, current in zip(reversed(points[:-1]), reversed(points[1:]), strict=True):
        if current.balance_minor <= previous.balance_minor:
            break
        rises += 1
    return rises


def next_debit_date(last_settlement: date | None) -> date | None:
    """A month after the last settlement: banks debit a card on the same day each month."""
    return add_months(last_settlement, 1) if last_settlement is not None else None


class AccountOverviewService:
    """Builds the account detail page's figures for one of the user's accounts."""

    def __init__(self, db: Session) -> None:
        self._db = db
        self._rules = SettlementRuleService(db)

    def overview(self, account: Account, read: AccountRead, today: date) -> AccountOverview:
        """The detail page's figures for ``account``, as of ``today``.

        ``read`` is the account as the API returns it, carried as-is into the result.
        """
        history = balance_history(account.opening_balance_minor, self._monthly_sums(account), today)
        is_card = account.type == "deferred_card"
        return AccountOverview(
            account=read,
            card_last_digits=card_digits(account) if is_card else None,
            first_transaction_date=self._db.scalar(
                select(func.min(Transaction.booked_date)).where(
                    Transaction.account_id == account.id
                )
            ),
            last_import_at=self._last_import_at(account),
            balance_history=history,
            period=self._period(account, history, today),
            linked_cards=[] if is_card else self._linked_cards(account, today),
            card_settlement=self._card_settlement(account, today) if is_card else None,
        )

    def _monthly_sums(self, account: Account) -> dict[tuple[int, int], int]:
        # `extract()` rather than `strftime()`, so the query keeps working on Postgres.
        year = extract("year", Transaction.booked_date)
        month = extract("month", Transaction.booked_date)
        rows = self._db.execute(
            select(year, month, func.sum(Transaction.amount_minor))
            .where(Transaction.account_id == account.id)
            .group_by(year, month)
        )
        return {(int(y), int(m)): int(total) for y, m, total in rows}

    def _last_import_at(self, account: Account) -> datetime | None:
        return self._db.scalar(
            select(func.max(ImportBatch.imported_at)).where(
                ImportBatch.account_id == account.id, ImportBatch.status != "failed"
            )
        )

    def _period(self, account: Account, history: list[BalancePoint], today: date) -> PeriodStats:
        since = month_end(add_months(today, -PERIOD_MONTHS))
        inflow, outflow = self._db.execute(
            select(
                func.coalesce(
                    func.sum(Transaction.amount_minor).filter(Transaction.amount_minor > 0), 0
                ),
                func.coalesce(
                    func.sum(Transaction.amount_minor).filter(Transaction.amount_minor < 0), 0
                ),
            ).where(Transaction.account_id == account.id, Transaction.booked_date > since)
        ).one()
        return PeriodStats(
            since=since,
            change_minor=inflow + outflow,
            inflow_minor=inflow,
            outflow_minor=outflow,
            consecutive_rising_months=consecutive_rises(history),
        )

    def _linked_cards(self, account: Account, today: date) -> list[LinkedCard]:
        cards = self._db.scalars(
            select(Account)
            .where(
                Account.user_id == account.user_id,
                Account.settlement_account_id == account.id,
                Account.type == "deferred_card",
                Account.archived.is_(False),
            )
            .order_by(Account.created_at)
        )
        issues = {
            issue.account_id: issue.issue for issue in self._rules.status(account.user_id).cards
        }
        linked: list[LinkedCard] = []
        for card in cards:
            settlements = self._settlements(card)
            last = settlements[-1].booked_date if settlements else None
            linked.append(
                LinkedCard(
                    id=card.id,
                    name=card.name,
                    institution=card.institution,
                    card_last_digits=card_digits(card),
                    cycle_amount_minor=self._open_cycle(card, last, today),
                    next_debit_date=next_debit_date(last),
                    issue=issues.get(card.id),
                )
            )
        return linked

    def _card_settlement(self, card: Account, today: date) -> CardSettlement:
        rule = self._rules.rule_for(card)
        settlements = self._settlements(card)
        last = settlements[-1].booked_date if settlements else None
        cycles = [
            SettlementCycle(settled_on=row.booked_date, amount_minor=row.amount_minor)
            for row in settlements
        ]
        cycles.append(
            SettlementCycle(settled_on=None, amount_minor=self._open_cycle(card, last, today))
        )
        return CardSettlement(
            settlement_account_id=card.settlement_account_id,
            rule=rule_read(rule) if rule is not None else None,
            cycles=cycles,
            next_debit_date=next_debit_date(last),
        )

    def _settlements(self, card: Account) -> list[Transaction]:
        """The debits on the card's paying account its enabled rule files, oldest first."""
        rule = self._rules.rule_for(card)
        if rule is None or not rule.enabled or card.settlement_account_id is None:
            return []
        paying = self._db.scalars(
            select(Transaction)
            .where(Transaction.account_id == card.settlement_account_id)
            .order_by(Transaction.booked_date)
        )
        return [row for row in paying if matches(row, rule)]

    def _open_cycle(self, card: Account, last_settlement: date | None, today: date) -> int:
        """What the open cycle holds: the card's rows since its last settlement.

        With no settlement known, the rows since the first of the month — the page labels the
        figure "this month so far", which is what it then is.
        """
        start_after = (
            last_settlement
            if last_settlement is not None
            else today.replace(day=1) - timedelta(days=1)
        )
        total = self._db.scalar(
            select(func.sum(Transaction.amount_minor)).where(
                Transaction.account_id == card.id, Transaction.booked_date > start_after
            )
        )
        return total or 0


def rule_read(rule: CategorizationRule) -> SettlementRuleRead:
    """The API shape of a card's settlement rule."""
    return SettlementRuleRead(
        id=rule.id,
        match_type=rule.match_type,
        pattern=rule.pattern,
        enabled=rule.enabled,
        applies_from=rule.applies_from,
    )
