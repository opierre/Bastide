"""Business logic for declared loans: CRUD and every figure derived from the schedule.

Nothing in here writes a transaction, moves a balance or persists a schedule row. A loan is
declared and standalone (§15); its schedule is a pure function of the row, built by the engine
once per loan per request and reused for every figure that request needs.
"""

from datetime import date
from typing import Any

from app.core.errors import NotFoundError, ValidationError
from app.features.auth.models import User
from app.features.mortgages.engine import (
    NonAmortizingLoanError,
    RepaymentType,
    Schedule,
    build_schedule,
    taeg_bps,
)
from app.features.mortgages.models import Mortgage
from app.features.mortgages.repository import MortgageRepository
from app.features.mortgages.schemas import (
    MortgageCreate,
    MortgageDetail,
    MortgageRead,
    MortgageStatus,
    MortgageUpdate,
    ScheduleGranularity,
    ScheduleMonthRow,
    ScheduleRead,
    ScheduleTotals,
    ScheduleYearRow,
)

ACTIVE: MortgageStatus = "active"
ARCHIVED: MortgageStatus = "archived"

#: What `GET /mortgages` returns without a `status` filter: every loan that is not archived.
DEFAULT_STATUSES: tuple[MortgageStatus, ...] = ("active", "repaid")

_BPS_PER_UNIT = 10_000

#: The columns the schedule is a function of — a patch touching none of them cannot break it.
_SCHEDULE_INPUTS = (
    "principal_minor",
    "annual_rate_bps",
    "term_months",
    "insurance_monthly_minor",
    "repayment_type",
    "first_payment_date",
    "upfront_fees_minor",
)


class MortgageNotFoundError(NotFoundError):
    """Raised when a loan doesn't exist or doesn't belong to the caller."""

    code = "MORTGAGE_NOT_FOUND"


class MortgagePropertyInvalidError(ValidationError):
    """Raised when `property_id` is not one of the caller's properties.

    The same answer for a missing property and another user's, so the error reveals nothing.
    """

    code = "MORTGAGE_PROPERTY_INVALID"


class MortgageNonAmortizingError(ValidationError):
    """Raised when the instalment does not repay the principal (§15: rejected, never grown)."""

    code = "MORTGAGE_NON_AMORTIZING"


class MortgageFeesExceedPrincipalError(ValidationError):
    """Raised when upfront fees swallow the principal, leaving no advance to rate a TAEG on."""

    code = "MORTGAGE_FEES_EXCEED_PRINCIPAL"


class MortgageScheduleWindowInvalidError(ValidationError):
    """Raised when a schedule window's `from` falls after its `to`."""

    code = "MORTGAGE_SCHEDULE_WINDOW_INVALID"


def schedule_for(mortgage: Mortgage) -> Schedule:
    """The loan's full schedule from the engine."""
    return build_schedule(
        principal_minor=mortgage.principal_minor,
        annual_rate_bps=mortgage.annual_rate_bps,
        term_months=mortgage.term_months,
        insurance_monthly_minor=mortgage.insurance_monthly_minor,
        repayment_type=RepaymentType(mortgage.repayment_type),
        first_payment_date=mortgage.first_payment_date,
        upfront_fees_minor=mortgage.upfront_fees_minor,
    )


def ratio_bps(numerator: int, denominator: int) -> int:
    """`numerator / denominator` in basis points, rounded half-up. Both non-negative."""
    return (2 * numerator * _BPS_PER_UNIT + denominator) // (2 * denominator)


def monthly_payment_minor(schedule: Schedule) -> int:
    """The échéance, insurance excluded: the first row, before any final-row residue."""
    first = schedule.rows[0]
    return first.interest_minor + first.principal_minor


def to_read(mortgage: Mortgage, schedule: Schedule, currency: str, today: date) -> MortgageRead:
    """The loan with its list figures as of `today`.

    A loan whose first instalment is still ahead owes its whole principal and has repaid
    nothing, which `outstanding_at` gives without special-casing.
    """
    outstanding = schedule.outstanding_at(today)
    upcoming = [row for row in schedule.rows if row.due_on > today]
    payment = monthly_payment_minor(schedule)
    return MortgageRead(
        id=mortgage.id,
        label=mortgage.label,
        lender=mortgage.lender,
        property_id=mortgage.property_id,
        # ty: ignore[invalid-argument-type] — the columns are plain str; the Literals are
        # enforced by the create/update schemas, which are the only writers of these fields.
        kind=mortgage.kind,
        # ty: ignore[invalid-argument-type] — see `kind`.
        repayment_type=mortgage.repayment_type,
        principal_minor=mortgage.principal_minor,
        annual_rate_bps=mortgage.annual_rate_bps,
        insurance_monthly_minor=mortgage.insurance_monthly_minor,
        term_months=mortgage.term_months,
        first_payment_date=mortgage.first_payment_date,
        upfront_fees_minor=mortgage.upfront_fees_minor,
        # ty: ignore[invalid-argument-type] — see `kind`.
        status=mortgage.status,
        currency=currency,
        monthly_payment_minor=payment,
        total_instalment_minor=payment + mortgage.insurance_monthly_minor,
        outstanding_principal_minor=outstanding,
        paid_principal_pct=ratio_bps(
            mortgage.principal_minor - outstanding, mortgage.principal_minor
        ),
        remaining_months=len(upcoming),
        next_payment_on=upcoming[0].due_on if upcoming else None,
        created_at=mortgage.created_at,
        updated_at=mortgage.updated_at,
    )


class MortgageService:
    """Loan CRUD and derived figures, scoped to a user."""

    def __init__(self, repository: MortgageRepository) -> None:
        self._repository = repository

    def list_for_user(
        self, user: User, today: date, status: MortgageStatus | None = None
    ) -> list[MortgageRead]:
        """The user's loans with their figures, oldest first.

        Archived loans are excluded unless asked for by name with `?status=archived`.
        """
        statuses = (status,) if status is not None else DEFAULT_STATUSES
        return [
            to_read(mortgage, schedule_for(mortgage), user.currency, today)
            for mortgage in self._repository.list_for_user(user.id, statuses)
        ]

    def get(self, user: User, mortgage_id: str, today: date) -> MortgageDetail:
        """One loan with its cost totals and TAEG.

        Raises:
            MortgageNotFoundError: no such loan, or it belongs to another user.
        """
        return self._detail(self._owned(user.id, mortgage_id), user.currency, today)

    def create(self, user: User, data: MortgageCreate, today: date) -> MortgageDetail:
        """Declare a loan. Currency is the user's; no debt-ratio reading ever refuses it (§15).

        Raises:
            MortgagePropertyInvalidError: `property_id` is not one of the user's properties.
            MortgageFeesExceedPrincipalError: the fees are not smaller than the principal.
            MortgageNonAmortizingError: the instalment does not repay the principal.
        """
        mortgage = Mortgage(user_id=user.id, status=ACTIVE, **data.model_dump())
        self._check_property(user.id, data.property_id)
        self._validated_schedule(mortgage)
        return self._detail(self._repository.add(mortgage), user.currency, today)

    def update(
        self, user: User, mortgage_id: str, data: MortgageUpdate, today: date
    ) -> MortgageDetail:
        """Patch a loan, including archiving, restoring and marking it repaid via `status`.

        The patch is validated against the merged row before anything is assigned, so a
        rejected edit leaves the loan exactly as it was.

        Raises:
            MortgageNotFoundError: no such loan, or it belongs to another user.
            MortgagePropertyInvalidError: `property_id` is not one of the user's properties.
            MortgageFeesExceedPrincipalError: the fees are not smaller than the principal.
            MortgageNonAmortizingError: the instalment does not repay the principal.
        """
        mortgage = self._owned(user.id, mortgage_id)
        changes: dict[str, Any] = data.model_dump(exclude_none=True)
        self._check_property(user.id, changes.get("property_id"))
        if any(field in changes for field in _SCHEDULE_INPUTS):
            merged = Mortgage(
                **{
                    field: changes.get(field, getattr(mortgage, field))
                    for field in _SCHEDULE_INPUTS
                }
            )
            self._validated_schedule(merged)
        for field, value in changes.items():
            setattr(mortgage, field, value)
        return self._detail(self._repository.save(mortgage), user.currency, today)

    def schedule(
        self,
        user: User,
        mortgage_id: str,
        *,
        start: date | None,
        end: date | None,
        granularity: ScheduleGranularity,
    ) -> ScheduleRead:
        """The instalments due in `[start, end]`, per month or summed per calendar year.

        Paged by date window rather than offset, because the panel reads a schedule a year at a
        time. Either bound may be open; the schedule itself ends at the loan's term, so an
        unbounded window is capped there with nothing to add beyond it.

        Raises:
            MortgageNotFoundError: no such loan, or it belongs to another user.
            MortgageScheduleWindowInvalidError: `start` is after `end`.
        """
        if start is not None and end is not None and start > end:
            raise MortgageScheduleWindowInvalidError("`from` must not be after `to`.")
        full = schedule_for(self._owned(user.id, mortgage_id))
        window = Schedule(
            principal_minor=full.principal_minor,
            upfront_fees_minor=full.upfront_fees_minor,
            rows=tuple(
                row
                for row in full.rows
                if (start is None or row.due_on >= start) and (end is None or row.due_on <= end)
            ),
        )
        rows: list[ScheduleMonthRow] | list[ScheduleYearRow]
        if granularity == "year":
            rows = [
                ScheduleYearRow(
                    year=year.year,
                    instalment_minor=year.instalment_minor,
                    interest_minor=year.interest_minor,
                    principal_minor=year.principal_minor,
                    insurance_minor=year.insurance_minor,
                    outstanding_after_minor=year.outstanding_end_minor,
                )
                for year in window.by_year()
            ]
        else:
            rows = [
                ScheduleMonthRow(
                    ordinal=row.ordinal,
                    due_on=row.due_on,
                    instalment_minor=row.instalment_minor,
                    interest_minor=row.interest_minor,
                    principal_minor=row.principal_minor,
                    insurance_minor=row.insurance_minor,
                    outstanding_after_minor=row.outstanding_after_minor,
                )
                for row in window.rows
            ]
        return ScheduleRead(
            granularity=granularity,
            rows=rows,
            totals=ScheduleTotals(
                interest_minor=window.total_interest_minor,
                principal_minor=sum(row.principal_minor for row in window.rows),
                insurance_minor=window.total_insurance_minor,
            ),
            currency=user.currency,
        )

    def archive(self, user_id: str, mortgage_id: str) -> None:
        """Archive a loan, as accounts and goals are archived, never hard-deleted.

        Raises:
            MortgageNotFoundError: no such loan, or it belongs to another user.
        """
        mortgage = self._owned(user_id, mortgage_id)
        mortgage.status = ARCHIVED
        self._repository.save(mortgage)

    def _owned(self, user_id: str, mortgage_id: str) -> Mortgage:
        mortgage = self._repository.get_for_user(mortgage_id, user_id)
        if mortgage is None:
            raise MortgageNotFoundError("Mortgage not found.")
        return mortgage

    def _check_property(self, user_id: str, property_id: str | None) -> None:
        if property_id is not None and not self._repository.property_belongs_to(
            property_id, user_id
        ):
            raise MortgagePropertyInvalidError("Property not found.")

    @staticmethod
    def _validated_schedule(mortgage: Mortgage) -> Schedule:
        """Build the schedule a write would commit to, refusing one the engine cannot draw."""
        if mortgage.upfront_fees_minor >= mortgage.principal_minor:
            raise MortgageFeesExceedPrincipalError(
                "Upfront fees must be smaller than the principal."
            )
        try:
            return schedule_for(mortgage)
        except NonAmortizingLoanError as exc:
            raise MortgageNonAmortizingError(
                "The instalment does not repay the principal.",
                details={"reason": str(exc)},
            ) from exc

    @staticmethod
    def _detail(mortgage: Mortgage, currency: str, today: date) -> MortgageDetail:
        schedule = schedule_for(mortgage)
        return MortgageDetail(
            **to_read(mortgage, schedule, currency, today).model_dump(),
            total_interest_minor=schedule.total_interest_minor,
            total_insurance_minor=schedule.total_insurance_minor,
            total_cost_minor=schedule.total_cost_minor,
            taeg_bps=taeg_bps(schedule),
            last_payment_on=schedule.rows[-1].due_on,
        )
