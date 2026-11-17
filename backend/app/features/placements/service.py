"""Business logic for placements: CRUD, the derived figures, the summary and the month series.

A placement is followed from the values the user declares; Bastide reads no price and touches
no account balance. Net payments, gain and age are derived on every read from the movements and
declared values (arithmetic in `engine`), never stored.
"""

from collections.abc import Sequence
from datetime import date, timedelta
from typing import Any
from uuid import uuid4

from app.core.errors import ConflictError, NotFoundError, ValidationError
from app.core.months import last_of_month, month_index, month_key
from app.features.auth.models import User
from app.features.placements.engine import (
    ENVELOPES,
    STALE_AFTER_MONTHS,
    Holding,
    add_months,
    ceiling_for,
    full_months_between,
    ratio_bps,
)
from app.features.placements.models import Investment, InvestmentMovement, InvestmentValuation
from app.features.placements.repository import PlacementRepository
from app.features.placements.schemas import (
    EnvelopeRead,
    InvestmentClose,
    InvestmentCreate,
    InvestmentDetail,
    InvestmentRead,
    InvestmentSeries,
    InvestmentSeriesPoint,
    InvestmentSummary,
    InvestmentUpdate,
    LinkCandidate,
    MovementCreate,
    MovementRead,
    MovementUpdate,
    ValuationCreate,
    ValuationRead,
    ValuationUpdate,
)

#: How far either side of a movement's date a funding transfer is looked for.
LINK_WINDOW_DAYS = 10
LINK_CANDIDATE_LIMIT = 20


class InvestmentNotFoundError(NotFoundError):
    """Raised when a placement doesn't exist or doesn't belong to the caller."""

    code = "INVESTMENT_NOT_FOUND"


class MovementNotFoundError(NotFoundError):
    """Raised when a movement doesn't exist on that placement."""

    code = "INVESTMENT_MOVEMENT_NOT_FOUND"


class ValuationNotFoundError(NotFoundError):
    """Raised when a declared value doesn't exist on that placement."""

    code = "INVESTMENT_VALUATION_NOT_FOUND"


class InvestmentDateInFutureError(ValidationError):
    """Raised when an opening, movement, value or closing date is ahead of today.

    A date in the future is a typo; carried into the net-worth series it would read as fact.
    """

    code = "INVESTMENT_DATE_IN_FUTURE"


class InvestmentDateBeforeOpeningError(ValidationError):
    """Raised when a movement or value predates the opening, or an opening postdates them."""

    code = "INVESTMENT_DATE_BEFORE_OPENING"


class InvestmentDateAfterClosingError(ValidationError):
    """Raised when a movement or value is dated after the closing, or a closing before them."""

    code = "INVESTMENT_DATE_AFTER_CLOSING"


class InvestmentAlreadyClosedError(ConflictError):
    """Raised when closing a placement that is already closed."""

    code = "INVESTMENT_ALREADY_CLOSED"


class InvestmentNotClosedError(ConflictError):
    """Raised when reopening a placement that is open."""

    code = "INVESTMENT_NOT_CLOSED"


class ValuationDateTakenError(ConflictError):
    """Raised when the placement already has a declared value on that date."""

    code = "INVESTMENT_VALUATION_EXISTS"


class LinkedTransactionNotFoundError(ValidationError):
    """Raised when the transaction to link is not one of the caller's."""

    code = "INVESTMENT_LINKED_TRANSACTION_NOT_FOUND"


class TransactionAlreadyLinkedError(ConflictError):
    """Raised when the transaction is already linked to another movement."""

    code = "INVESTMENT_TRANSACTION_ALREADY_LINKED"


def envelope_catalogue(currency: str) -> list[EnvelopeRead]:
    """The envelope catalogue, ceilings shown only to a user in the catalogue's currency."""
    return [
        EnvelopeRead(
            # ty: ignore[invalid-argument-type] — the keys of ENVELOPES are the Envelope literal.
            key=key,
            payment_ceiling_minor=ceiling_for(key, currency),
            milestone_years=rule.milestone_years,
        )
        for key, rule in ENVELOPES.items()
    ]


def to_holding(
    investment: Investment,
    movements: Sequence[InvestmentMovement],
    valuations: Sequence[InvestmentValuation],
) -> Holding:
    """The placement's dated history, as the engine values it."""
    return Holding(
        envelope=investment.envelope,
        opened_on=investment.opened_on,
        closed_on=investment.closed_on,
        movements=tuple((m.occurred_on, m.amount_minor) for m in movements),
        valuations=tuple((v.valued_on, v.value_minor) for v in valuations),
    )


def to_read(
    investment: Investment,
    movements: Sequence[InvestmentMovement],
    valuations: Sequence[InvestmentValuation],
    today: date,
) -> InvestmentRead:
    """The placement with every derived figure. Nothing computed here is stored."""
    paid_in = sum(m.amount_minor for m in movements if m.amount_minor > 0)
    withdrawn = sum(m.amount_minor for m in movements if m.amount_minor < 0)
    net = paid_in + withdrawn
    last = max(valuations, key=lambda v: v.valued_on, default=None)
    is_open = investment.closed_on is None
    gain = last.value_minor - net if last is not None and is_open else None
    reference = investment.closed_on or today
    rule = ENVELOPES[investment.envelope]
    milestone_on = (
        add_months(investment.opened_on, 12 * rule.milestone_years)
        if rule.milestone_years is not None
        else None
    )
    return InvestmentRead(
        id=investment.id,
        name=investment.name,
        institution=investment.institution,
        # ty: ignore[invalid-argument-type] — the column is plain str; the Literal is enforced
        # by the create/update schemas, the only writers of this field.
        envelope=investment.envelope,
        opened_on=investment.opened_on,
        closed_on=investment.closed_on,
        currency=investment.currency,
        paid_in_minor=paid_in,
        withdrawn_minor=withdrawn,
        net_payments_minor=net,
        last_value_minor=last.value_minor if last is not None else None,
        last_valued_on=last.valued_on if last is not None else None,
        unrealised_gain_minor=gain,
        gain_bps=ratio_bps(gain, net) if gain is not None else None,
        value_stale=(
            is_open and last is not None and last.valued_on < add_months(today, -STALE_AFTER_MONTHS)
        ),
        age_months=full_months_between(investment.opened_on, reference),
        payment_ceiling_minor=ceiling_for(investment.envelope, investment.currency),
        milestone_years=rule.milestone_years,
        milestone_on=milestone_on,
        milestone_reached=milestone_on is not None and reference >= milestone_on,
        movement_count=len(movements),
        linked_movement_count=sum(1 for m in movements if m.transaction_id is not None),
        created_at=investment.created_at,
        updated_at=investment.updated_at,
    )


class PlacementService:
    """Placement CRUD, history, and the figures derived from it, scoped to a user."""

    def __init__(self, repository: PlacementRepository) -> None:
        self._repository = repository

    # --- reads --------------------------------------------------------------------------------

    def list_for_user(self, user: User, today: date) -> list[InvestmentRead]:
        """Every placement of the user's, open ones first, closed ones last."""
        investments = self._repository.list_for_user(user.id)
        movements, valuations = self._histories(investments)
        return [
            to_read(inv, movements.get(inv.id, []), valuations.get(inv.id, []), today)
            for inv in investments
        ]

    def get(self, user: User, investment_id: str, today: date) -> InvestmentDetail:
        """One placement with its full history.

        Raises:
            InvestmentNotFoundError: no such placement, or it belongs to another user.
        """
        return self._detail(self._owned(user.id, investment_id), today)

    def summary(self, user: User, today: date) -> InvestmentSummary:
        """The summary line over the open placements."""
        reads = self.list_for_user(user, today)
        open_reads = [read for read in reads if read.closed_on is None]
        valued = [read for read in open_reads if read.last_value_minor is not None]
        gain = sum(read.unrealised_gain_minor or 0 for read in valued)
        return InvestmentSummary(
            open_count=len(open_reads),
            closed_count=len(reads) - len(open_reads),
            declared_value_minor=sum(read.last_value_minor or 0 for read in valued),
            net_payments_minor=sum(read.net_payments_minor for read in open_reads),
            unrealised_gain_minor=gain,
            gain_bps=(
                ratio_bps(gain, sum(read.net_payments_minor for read in valued)) if valued else None
            ),
            valued_count=len(valued),
            stale_count=sum(1 for read in open_reads if read.value_stale),
            last_valued_on=max(
                (read.last_valued_on for read in valued if read.last_valued_on is not None),
                default=None,
            ),
            currency=user.currency,
        )

    def series(self, user: User, today: date) -> InvestmentSeries:
        """The placements at each closed month end, from the first opening to last month.

        The value is what net worth counts (`Holding.value_on`); net payments count only the
        placements held at that month end.
        """
        investments = self._repository.list_for_user(user.id)
        movements, valuations = self._histories(investments)
        holdings = [
            to_holding(inv, movements.get(inv.id, []), valuations.get(inv.id, []))
            for inv in investments
        ]
        points: list[InvestmentSeriesPoint] = []
        if holdings:
            first = min(month_index(h.opened_on) for h in holdings)
            for month in range(first, month_index(today)):
                month_end = last_of_month(month)
                held = [h for h in holdings if h.is_held_on(month_end)]
                points.append(
                    InvestmentSeriesPoint(
                        month=month_key(month),
                        value_minor=sum(h.value_on(month_end) for h in held),
                        net_payments_minor=sum(h.net_payments_on(month_end) for h in held),
                    )
                )
        return InvestmentSeries(points=points, currency=user.currency)

    def link_candidates(
        self,
        user: User,
        investment_id: str,
        amount_minor: int,
        around: date,
        movement_id: str | None,
    ) -> list[LinkCandidate]:
        """The caller's transactions that may have funded a movement of `amount_minor`.

        A payment in is funded by money leaving an account, so the match is the opposite
        amount, booked within `LINK_WINDOW_DAYS` of `around`, not linked to another movement
        (`movement_id`'s own link is kept). Nearest date first.

        Raises:
            InvestmentNotFoundError: no such placement, or it belongs to another user.
        """
        self._owned(user.id, investment_id)
        window = timedelta(days=LINK_WINDOW_DAYS)
        rows = self._repository.link_candidates(
            user.id, -amount_minor, around - window, around + window, movement_id
        )
        rows.sort(key=lambda row: (abs((row[0].booked_date - around).days), row[0].id))
        return [
            LinkCandidate(
                transaction_id=transaction.id,
                account_id=transaction.account_id,
                account_name=account_name,
                booked_date=transaction.booked_date,
                amount_minor=transaction.amount_minor,
                currency=transaction.currency,
                description=transaction.description_clean,
            )
            for transaction, account_name in rows[:LINK_CANDIDATE_LIMIT]
        ]

    # --- placements ---------------------------------------------------------------------------

    def create(self, user: User, data: InvestmentCreate, today: date) -> InvestmentDetail:
        """Create a placement, with its opening payments and current value when given.

        Raises:
            InvestmentDateInFutureError: the opening or value date is ahead of today.
            InvestmentDateBeforeOpeningError: the value is dated before the opening.
        """
        _not_future(data.opened_on, today)
        valued_on = data.initial_value_on or today
        if data.initial_value_minor is not None:
            _not_future(valued_on, today)
            _not_before_opening(valued_on, data.opened_on)
        # The id is set here rather than at insert so the opening history can point at it.
        investment = Investment(
            id=str(uuid4()),
            user_id=user.id,
            name=data.name,
            institution=data.institution,
            envelope=data.envelope,
            opened_on=data.opened_on,
            currency=user.currency,
        )
        rows: list[Investment | InvestmentMovement | InvestmentValuation] = [investment]
        if data.initial_payments_minor is not None:
            rows.append(
                InvestmentMovement(
                    investment_id=investment.id,
                    occurred_on=data.opened_on,
                    amount_minor=data.initial_payments_minor,
                    currency=user.currency,
                )
            )
        if data.initial_value_minor is not None:
            rows.append(
                InvestmentValuation(
                    investment_id=investment.id,
                    valued_on=valued_on,
                    value_minor=data.initial_value_minor,
                    currency=user.currency,
                )
            )
        self._repository.add(*rows)
        return self._detail(investment, today)

    def update(
        self, user: User, investment_id: str, data: InvestmentUpdate, today: date
    ) -> InvestmentDetail:
        """Patch a placement. The patch is checked whole before anything is assigned.

        Raises:
            InvestmentNotFoundError: no such placement, or it belongs to another user.
            InvestmentDateInFutureError: the new opening date is ahead of today.
            InvestmentDateBeforeOpeningError: the new opening date postdates its history.
        """
        investment = self._owned(user.id, investment_id)
        changes: dict[str, Any] = data.model_dump(exclude_none=True)
        if "opened_on" in changes:
            opened_on: date = changes["opened_on"]
            _not_future(opened_on, today)
            earliest, _ = self._repository.history_bounds(investment.id)
            if earliest is not None:
                _not_before_opening(earliest, opened_on)
            if investment.closed_on is not None and opened_on > investment.closed_on:
                raise InvestmentDateAfterClosingError(
                    "A placement cannot open after it closed.",
                    details={"closed_on": investment.closed_on.isoformat()},
                )
        for field, value in changes.items():
            setattr(investment, field, value)
        self._repository.save()
        return self._detail(investment, today)

    def delete(self, user: User, investment_id: str) -> None:
        """Delete a placement and its whole history (closing is how to keep it).

        Raises:
            InvestmentNotFoundError: no such placement, or it belongs to another user.
        """
        self._repository.delete_investment(self._owned(user.id, investment_id))

    def close(
        self, user: User, investment_id: str, data: InvestmentClose, today: date
    ) -> InvestmentDetail:
        """Close a placement: it leaves net worth from `closed_on` and stays listed.

        A positive final amount is recorded as a withdrawal on the closing date.

        Raises:
            InvestmentNotFoundError: no such placement, or it belongs to another user.
            InvestmentAlreadyClosedError: it is already closed.
            InvestmentDateInFutureError: `closed_on` is ahead of today.
            InvestmentDateBeforeOpeningError: `closed_on` is before the opening.
            InvestmentDateAfterClosingError: its history runs past `closed_on`.
        """
        investment = self._owned(user.id, investment_id)
        if investment.closed_on is not None:
            raise InvestmentAlreadyClosedError(
                "The placement is already closed.",
                details={"closed_on": investment.closed_on.isoformat()},
            )
        _not_future(data.closed_on, today)
        _not_before_opening(data.closed_on, investment.opened_on)
        _, latest = self._repository.history_bounds(investment.id)
        if latest is not None and latest > data.closed_on:
            raise InvestmentDateAfterClosingError(
                "The placement has movements or values after that closing date.",
                details={"latest": latest.isoformat()},
            )
        investment.closed_on = data.closed_on
        if data.final_amount_minor > 0:
            self._repository.add(
                InvestmentMovement(
                    investment_id=investment.id,
                    occurred_on=data.closed_on,
                    amount_minor=-data.final_amount_minor,
                    currency=investment.currency,
                )
            )
        else:
            self._repository.save()
        return self._detail(investment, today)

    def reopen(self, user: User, investment_id: str, today: date) -> InvestmentDetail:
        """Undo a closing. The final withdrawal it recorded stays, as any movement does.

        Raises:
            InvestmentNotFoundError: no such placement, or it belongs to another user.
            InvestmentNotClosedError: it is open.
        """
        investment = self._owned(user.id, investment_id)
        if investment.closed_on is None:
            raise InvestmentNotClosedError("The placement is not closed.")
        investment.closed_on = None
        self._repository.save()
        return self._detail(investment, today)

    # --- movements ----------------------------------------------------------------------------

    def add_movement(
        self, user: User, investment_id: str, data: MovementCreate, today: date
    ) -> MovementRead:
        """Record a payment in or a withdrawal.

        Raises:
            InvestmentNotFoundError: no such placement, or it belongs to another user.
            InvestmentDateInFutureError / InvestmentDateBeforeOpeningError /
                InvestmentDateAfterClosingError: the date falls outside the placement's life.
            LinkedTransactionNotFoundError: the transaction is not one of the caller's.
            TransactionAlreadyLinkedError: it is linked to another movement.
        """
        investment = self._owned(user.id, investment_id)
        self._check_date(investment, data.occurred_on, today)
        if data.transaction_id is not None:
            self._check_link(user.id, data.transaction_id, None)
        movement = InvestmentMovement(
            investment_id=investment.id,
            occurred_on=data.occurred_on,
            amount_minor=data.amount_minor,
            currency=investment.currency,
            note=data.note,
            transaction_id=data.transaction_id,
        )
        self._repository.add(movement)
        return MovementRead.model_validate(movement)

    def update_movement(
        self,
        user: User,
        investment_id: str,
        movement_id: str,
        data: MovementUpdate,
        today: date,
    ) -> MovementRead:
        """Patch a movement; `note` and `transaction_id` sent as null are cleared.

        Raises:
            InvestmentNotFoundError / MovementNotFoundError: not the caller's.
            The date and link errors of `add_movement`.
        """
        investment = self._owned(user.id, investment_id)
        movement = self._repository.get_movement(movement_id, investment.id)
        if movement is None:
            raise MovementNotFoundError("Movement not found.")
        if data.occurred_on is not None:
            self._check_date(investment, data.occurred_on, today)
            movement.occurred_on = data.occurred_on
        if data.amount_minor is not None:
            movement.amount_minor = data.amount_minor
        if "note" in data.model_fields_set:
            movement.note = data.note
        if "transaction_id" in data.model_fields_set:
            if data.transaction_id is not None:
                self._check_link(user.id, data.transaction_id, movement.id)
            movement.transaction_id = data.transaction_id
        self._repository.save()
        return MovementRead.model_validate(movement)

    def delete_movement(self, user: User, investment_id: str, movement_id: str) -> None:
        """Delete a movement.

        Raises:
            InvestmentNotFoundError / MovementNotFoundError: not the caller's.
        """
        investment = self._owned(user.id, investment_id)
        movement = self._repository.get_movement(movement_id, investment.id)
        if movement is None:
            raise MovementNotFoundError("Movement not found.")
        self._repository.delete(movement)

    # --- declared values ----------------------------------------------------------------------

    def add_valuation(
        self, user: User, investment_id: str, data: ValuationCreate, today: date
    ) -> ValuationRead:
        """Record the value copied from a statement.

        Raises:
            InvestmentNotFoundError: no such placement, or it belongs to another user.
            The date errors of `add_movement`.
            ValuationDateTakenError: a value is already declared on that date.
        """
        investment = self._owned(user.id, investment_id)
        self._check_date(investment, data.valued_on, today)
        self._check_valuation_date_free(investment.id, data.valued_on, None)
        valuation = InvestmentValuation(
            investment_id=investment.id,
            valued_on=data.valued_on,
            value_minor=data.value_minor,
            currency=investment.currency,
            note=data.note,
        )
        self._repository.add(valuation)
        return ValuationRead.model_validate(valuation)

    def update_valuation(
        self,
        user: User,
        investment_id: str,
        valuation_id: str,
        data: ValuationUpdate,
        today: date,
    ) -> ValuationRead:
        """Patch a declared value; `note` sent as null is cleared.

        Raises:
            InvestmentNotFoundError / ValuationNotFoundError: not the caller's.
            The date errors of `add_valuation`.
        """
        investment = self._owned(user.id, investment_id)
        valuation = self._repository.get_valuation(valuation_id, investment.id)
        if valuation is None:
            raise ValuationNotFoundError("Value not found.")
        if data.valued_on is not None:
            self._check_date(investment, data.valued_on, today)
            self._check_valuation_date_free(investment.id, data.valued_on, valuation.id)
            valuation.valued_on = data.valued_on
        if data.value_minor is not None:
            valuation.value_minor = data.value_minor
        if "note" in data.model_fields_set:
            valuation.note = data.note
        self._repository.save()
        return ValuationRead.model_validate(valuation)

    def delete_valuation(self, user: User, investment_id: str, valuation_id: str) -> None:
        """Delete a declared value.

        Raises:
            InvestmentNotFoundError / ValuationNotFoundError: not the caller's.
        """
        investment = self._owned(user.id, investment_id)
        valuation = self._repository.get_valuation(valuation_id, investment.id)
        if valuation is None:
            raise ValuationNotFoundError("Value not found.")
        self._repository.delete(valuation)

    # --- helpers ------------------------------------------------------------------------------

    def _owned(self, user_id: str, investment_id: str) -> Investment:
        investment = self._repository.get_for_user(investment_id, user_id)
        if investment is None:
            raise InvestmentNotFoundError("Placement not found.")
        return investment

    def _histories(
        self, investments: Sequence[Investment]
    ) -> tuple[dict[str, list[InvestmentMovement]], dict[str, list[InvestmentValuation]]]:
        ids = [inv.id for inv in investments]
        movements: dict[str, list[InvestmentMovement]] = {}
        for movement in self._repository.movements_for(ids):
            movements.setdefault(movement.investment_id, []).append(movement)
        valuations: dict[str, list[InvestmentValuation]] = {}
        for valuation in self._repository.valuations_for(ids):
            valuations.setdefault(valuation.investment_id, []).append(valuation)
        return movements, valuations

    def _detail(self, investment: Investment, today: date) -> InvestmentDetail:
        movements = self._repository.movements_for([investment.id])
        valuations = self._repository.valuations_for([investment.id])
        return InvestmentDetail(
            **to_read(investment, movements, valuations, today).model_dump(),
            movements=[MovementRead.model_validate(m) for m in movements],
            valuations=[ValuationRead.model_validate(v) for v in valuations],
        )

    @staticmethod
    def _check_date(investment: Investment, day: date, today: date) -> None:
        _not_future(day, today)
        _not_before_opening(day, investment.opened_on)
        if investment.closed_on is not None and day > investment.closed_on:
            raise InvestmentDateAfterClosingError(
                "The date is after the placement was closed.",
                details={"date": day.isoformat(), "closed_on": investment.closed_on.isoformat()},
            )

    def _check_link(self, user_id: str, transaction_id: str, movement_id: str | None) -> None:
        if self._repository.user_transaction(transaction_id, user_id) is None:
            raise LinkedTransactionNotFoundError(
                "Transaction not found.", details={"transaction_id": transaction_id}
            )
        linked = self._repository.movement_linked_to(transaction_id)
        if linked is not None and linked.id != movement_id:
            raise TransactionAlreadyLinkedError(
                "The transaction is already linked to another movement.",
                details={"transaction_id": transaction_id},
            )

    def _check_valuation_date_free(
        self, investment_id: str, valued_on: date, valuation_id: str | None
    ) -> None:
        existing = self._repository.valuation_on(investment_id, valued_on)
        if existing is not None and existing.id != valuation_id:
            raise ValuationDateTakenError(
                "A value is already declared on that date.",
                details={"valued_on": valued_on.isoformat()},
            )


def _not_future(day: date, today: date) -> None:
    if day > today:
        raise InvestmentDateInFutureError(
            "A date must not be in the future.",
            details={"date": day.isoformat(), "today": today.isoformat()},
        )


def _not_before_opening(day: date, opened_on: date) -> None:
    if day < opened_on:
        raise InvestmentDateBeforeOpeningError(
            "A date must not be before the placement's opening date.",
            details={"date": day.isoformat(), "opened_on": opened_on.isoformat()},
        )
