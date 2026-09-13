"""The simulator (§17): a stateless compute over the mortgages engine.

It lives inside the mortgages feature because it computes through that feature's engine — one
implementation, so a simulated loan and a declared one can never disagree about the same inputs.
Nothing computed here is ever persisted.
"""

from datetime import date

from app.features.auth.models import User
from app.features.mortgages.engine import (
    NonAmortizingLoanError,
    RepaymentType,
    Schedule,
    build_schedule,
    taeg_bps,
)
from app.features.mortgages.repository import MortgageRepository
from app.features.mortgages.schemas import (
    HcsfReading,
    SimulationCompute,
    SimulationResult,
    SimulationYearRow,
)
from app.features.mortgages.service import (
    ACTIVE,
    HCSF_LIMIT_KEY,
    MortgageFeesExceedPrincipalError,
    MortgageNonAmortizingError,
    MortgageParameterMissingError,
    MortgageService,
    monthly_payment_minor,
    ratio_bps,
    schedule_for,
)

_BPS_PER_UNIT = 10_000
_MONTHS_PER_YEAR = 12

#: The seeded §15 maximum term the simulation's duration is read against.
HCSF_MAX_TERM_KEY = "hcsf_max_term_months_count"


def first_payment_date(today: date) -> date:
    """A simulated loan's first instalment: the first day of the month after `today`.

    The simulator takes no date, yet the yearly rows are calendar years, so the loan is dated as
    if signed now.
    """
    month_index = today.year * _MONTHS_PER_YEAR + today.month
    return date(month_index // _MONTHS_PER_YEAR, month_index % _MONTHS_PER_YEAR + 1, 1)


def scaled_insurance_minor(insurance_minor: int, reference_minor: int, principal_minor: int) -> int:
    """The insurance premium held at the reference loan's ratio, for another principal.

    Rounded half-up. Scaling it with the principal is what makes a borrowing capacity answer
    "how much house", not "how much principal at exactly this premium".
    """
    return (2 * insurance_minor * principal_minor + reference_minor) // (2 * reference_minor)


def simulated_schedule(
    *,
    principal_minor: int,
    annual_rate_bps: int,
    insurance_monthly_minor: int,
    term_months: int,
    upfront_fees_minor: int,
    first_payment_on: date,
) -> Schedule:
    """The engine's schedule for simulator inputs: constant payment, first instalment dated.

    Refuses what a declared loan refuses, with the same errors (P3-04 step 1).

    Raises:
        MortgageFeesExceedPrincipalError: the fees are not smaller than the principal.
        MortgageNonAmortizingError: the instalment does not repay the principal.
    """
    if upfront_fees_minor >= principal_minor:
        raise MortgageFeesExceedPrincipalError("Upfront fees must be smaller than the principal.")
    try:
        return build_schedule(
            principal_minor=principal_minor,
            annual_rate_bps=annual_rate_bps,
            term_months=term_months,
            insurance_monthly_minor=insurance_monthly_minor,
            repayment_type=RepaymentType.CONSTANT_PAYMENT,
            first_payment_date=first_payment_on,
            upfront_fees_minor=upfront_fees_minor,
        )
    except NonAmortizingLoanError as exc:
        raise MortgageNonAmortizingError(
            "The instalment does not repay the principal.", details={"reason": str(exc)}
        ) from exc


class SimulationService:
    """The stateless simulation, scoped to a user only for income, loans and parameters."""

    def __init__(self, mortgages: MortgageRepository) -> None:
        self._mortgages = mortgages
        # Income resolution is P3-04's, shared unchanged.
        self._mortgage_service = MortgageService(mortgages)

    def compute(self, user: User, data: SimulationCompute, today: date) -> SimulationResult:
        """Cost, yearly projection and HCSF reading of a loan nobody has declared.

        Writes nothing. An HCSF breach is reported, never refused (§15, §17).

        Raises:
            MortgageFeesExceedPrincipalError: the fees are not smaller than the principal.
            MortgageNonAmortizingError: the instalment does not repay the principal.
            MortgageParameterMissingError: an HCSF reference is neither seeded nor overridden.
        """
        limit_bps = self._parameter(user.id, HCSF_LIMIT_KEY)
        max_term_months = self._parameter(user.id, HCSF_MAX_TERM_KEY)
        first_on = first_payment_date(today)

        schedule = simulated_schedule(
            principal_minor=data.principal_minor,
            annual_rate_bps=data.annual_rate_bps,
            insurance_monthly_minor=data.insurance_monthly_minor,
            term_months=data.term_months,
            upfront_fees_minor=data.upfront_fees_minor,
            first_payment_on=first_on,
        )
        payment = monthly_payment_minor(schedule)
        instalment = payment + data.insurance_monthly_minor

        existing_charge = self._existing_charge(user.id) if data.include_existing_loans else 0
        income, _ = self._mortgage_service.monthly_income(user.id, today)

        debt_ratio: int | None = None
        available: int | None = None
        max_borrowable: int | None = None
        if income is not None and income > 0:
            debt_ratio = ratio_bps(instalment + existing_charge, income)
            available = max(limit_bps * income // _BPS_PER_UNIT - existing_charge, 0)
            max_borrowable = self._max_borrowable(data, available, first_on)

        return SimulationResult(
            monthly_payment_minor=payment,
            total_instalment_minor=instalment,
            total_interest_minor=schedule.total_interest_minor,
            total_insurance_minor=schedule.total_insurance_minor,
            total_cost_minor=schedule.total_cost_minor,
            cost_over_price_bps=(
                ratio_bps(schedule.total_cost_minor, data.property_price_minor)
                if data.property_price_minor
                else None
            ),
            taeg_bps=taeg_bps(schedule),
            yearly=[
                SimulationYearRow(
                    year=year.year,
                    instalment_minor=year.instalment_minor,
                    interest_minor=year.interest_minor,
                    principal_minor=year.principal_minor,
                    insurance_minor=year.insurance_minor,
                    outstanding_after_minor=year.outstanding_end_minor,
                )
                for year in schedule.by_year()
            ],
            debt_ratio_bps=debt_ratio,
            hcsf=HcsfReading(
                within_ratio=None if debt_ratio is None else debt_ratio <= limit_bps,
                within_term=data.term_months <= max_term_months,
                limit_bps=limit_bps,
                max_term_months=max_term_months,
            ),
            max_borrowable_minor=max_borrowable,
            available_instalment_minor=available,
            currency=user.currency,
        )

    def _existing_charge(self, user_id: str) -> int:
        """The monthly charge of the user's active loans, insurance included, as the summary's."""
        return sum(
            monthly_payment_minor(schedule_for(mortgage)) + mortgage.insurance_monthly_minor
            for mortgage in self._mortgages.list_for_user(user_id, (ACTIVE,))
        )

    @staticmethod
    def _max_borrowable(data: SimulationCompute, available_minor: int, first_on: date) -> int:
        """The largest principal whose instalment fits in `available_minor`.

        Bisection on the principal through the engine itself, with the insurance held at the
        simulation's ratio, so the capacity can never drift from the forward computation. The
        instalment only grows with the principal, so the search is monotone.
        """

        def fits(principal_minor: int) -> bool:
            insurance = scaled_insurance_minor(
                data.insurance_monthly_minor, data.principal_minor, principal_minor
            )
            try:
                schedule = build_schedule(
                    principal_minor=principal_minor,
                    annual_rate_bps=data.annual_rate_bps,
                    term_months=data.term_months,
                    insurance_monthly_minor=insurance,
                    repayment_type=RepaymentType.CONSTANT_PAYMENT,
                    first_payment_date=first_on,
                    upfront_fees_minor=0,
                )
            except NonAmortizingLoanError:
                # Only a principal a few cents wide rounds its instalment to nothing.
                return True
            return monthly_payment_minor(schedule) + insurance <= available_minor

        if available_minor <= 0:
            return 0
        low, high = 0, data.principal_minor
        while fits(high):
            low, high = high, high * 2
        while high - low > 1:
            middle = (low + high) // 2
            if fits(middle):
                low = middle
            else:
                high = middle
        return low

    def _parameter(self, user_id: str, key: str) -> int:
        value = self._mortgages.parameter_int(user_id, key)
        if value is None:
            raise MortgageParameterMissingError(f"Parameter '{key}' is not seeded.")
        return value
