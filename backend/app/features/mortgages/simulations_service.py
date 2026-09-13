"""The simulator (§17): a stateless compute over the mortgages engine, and saved scenarios.

It lives inside the mortgages feature because it computes through that feature's engine — one
implementation, so a simulated loan and a declared one can never disagree about the same inputs.
Nothing computed here is ever persisted: a saved scenario holds inputs only.
"""

from datetime import date
from typing import Any

from app.core.errors import NotFoundError, ValidationError
from app.core.months import first_of_month, month_index
from app.features.auth.models import User
from app.features.mortgages.engine import (
    NonAmortizingLoanError,
    RepaymentType,
    Schedule,
    build_schedule,
    taeg_bps,
)
from app.features.mortgages.models import MortgageSimulation
from app.features.mortgages.repository import MortgageRepository, SimulationRepository
from app.features.mortgages.schemas import (
    HcsfReading,
    SimulationCompute,
    SimulationCreate,
    SimulationRead,
    SimulationResult,
    SimulationUpdate,
    SimulationYearRow,
)
from app.features.mortgages.service import (
    ACTIVE,
    HCSF_LIMIT_BPS,
    MortgageFeesExceedPrincipalError,
    MortgageNonAmortizingError,
    MortgageService,
    monthly_payment_minor,
    ratio_bps,
    schedule_for,
)

_BPS_PER_UNIT = 10_000

#: The §15 maximum term the simulation's duration is read against: 25 years — the same HCSF
#: decision (the 27-year VEFA allowance for deferred amortisation is not modelled).
HCSF_MAX_TERM_MONTHS = 300

#: The panel compares at most 3 (§17); an unbounded list is a list nobody curates.
MAX_SIMULATIONS_PER_USER = 20

#: Validating a saved scenario needs a dated schedule, but no amount depends on the date.
_VALIDATION_FIRST_PAYMENT = date(2000, 1, 1)

#: The columns a scenario's schedule is a function of.
_SCHEDULE_INPUTS = (
    "principal_minor",
    "annual_rate_bps",
    "insurance_monthly_minor",
    "term_months",
    "upfront_fees_minor",
)


class SimulationNotFoundError(NotFoundError):
    """Raised when a scenario doesn't exist or doesn't belong to the caller."""

    code = "SIMULATION_NOT_FOUND"


class SimulationLimitReachedError(ValidationError):
    """Raised when saving one more scenario would exceed the per-user cap."""

    code = "SIMULATION_LIMIT_REACHED"


def first_payment_date(today: date) -> date:
    """A simulated loan's first instalment: the first day of the month after `today`.

    The simulator takes no date, yet the yearly rows are calendar years, so the loan is dated as
    if signed now.
    """
    return first_of_month(month_index(today) + 1)


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


def to_read(simulation: MortgageSimulation, currency: str) -> SimulationRead:
    return SimulationRead(
        id=simulation.id,
        label=simulation.label,
        property_price_minor=simulation.property_price_minor,
        down_payment_minor=simulation.down_payment_minor,
        principal_minor=simulation.principal_minor,
        annual_rate_bps=simulation.annual_rate_bps,
        insurance_monthly_minor=simulation.insurance_monthly_minor,
        term_months=simulation.term_months,
        upfront_fees_minor=simulation.upfront_fees_minor,
        currency=currency,
        created_at=simulation.created_at,
        updated_at=simulation.updated_at,
    )


class SimulationService:
    """The stateless simulation and the user's saved scenarios."""

    def __init__(self, mortgages: MortgageRepository, simulations: SimulationRepository) -> None:
        self._mortgages = mortgages
        self._simulations = simulations
        # Income resolution is P3-04's, shared unchanged.
        self._mortgage_service = MortgageService(mortgages)

    def list_for_user(self, user: User) -> list[SimulationRead]:
        """The user's saved scenarios, oldest first."""
        return [
            to_read(simulation, user.currency)
            for simulation in self._simulations.list_for_user(user.id)
        ]

    def create(self, user: User, data: SimulationCreate) -> SimulationRead:
        """Save a scenario's inputs. No HCSF reading ever refuses it (§15, §17).

        Raises:
            SimulationLimitReachedError: the user already holds the maximum number of scenarios.
            MortgageFeesExceedPrincipalError: the fees are not smaller than the principal.
            MortgageNonAmortizingError: the instalment does not repay the principal.
        """
        if self._simulations.count_for_user(user.id) >= MAX_SIMULATIONS_PER_USER:
            raise SimulationLimitReachedError(
                "Too many saved scenarios.", details={"limit": MAX_SIMULATIONS_PER_USER}
            )
        simulation = MortgageSimulation(user_id=user.id, **data.model_dump())
        self._validate(simulation)
        return to_read(self._simulations.add(simulation), user.currency)

    def update(self, user: User, simulation_id: str, data: SimulationUpdate) -> SimulationRead:
        """Patch a scenario, validated against the merged inputs before anything is assigned.

        Raises:
            SimulationNotFoundError: no such scenario, or it belongs to another user.
            MortgageFeesExceedPrincipalError: the fees are not smaller than the principal.
            MortgageNonAmortizingError: the instalment does not repay the principal.
        """
        simulation = self._owned(user.id, simulation_id)
        changes: dict[str, Any] = data.model_dump(exclude_none=True)
        if any(field in changes for field in _SCHEDULE_INPUTS):
            self._validate(
                MortgageSimulation(
                    **{
                        field: changes.get(field, getattr(simulation, field))
                        for field in _SCHEDULE_INPUTS
                    }
                )
            )
        for field, value in changes.items():
            setattr(simulation, field, value)
        return to_read(self._simulations.save(simulation), user.currency)

    def delete(self, user_id: str, simulation_id: str) -> None:
        """Hard-delete a scenario: archiving a scratchpad would leave debris nobody can clear.

        Raises:
            SimulationNotFoundError: no such scenario, or it belongs to another user.
        """
        self._simulations.delete(self._owned(user_id, simulation_id))

    def _owned(self, user_id: str, simulation_id: str) -> MortgageSimulation:
        simulation = self._simulations.get_for_user(simulation_id, user_id)
        if simulation is None:
            raise SimulationNotFoundError("Simulation not found.")
        return simulation

    @staticmethod
    def _validate(simulation: MortgageSimulation) -> None:
        simulated_schedule(
            principal_minor=simulation.principal_minor,
            annual_rate_bps=simulation.annual_rate_bps,
            insurance_monthly_minor=simulation.insurance_monthly_minor,
            term_months=simulation.term_months,
            upfront_fees_minor=simulation.upfront_fees_minor,
            first_payment_on=_VALIDATION_FIRST_PAYMENT,
        )

    def compute(self, user: User, data: SimulationCompute, today: date) -> SimulationResult:
        """Cost, yearly projection and HCSF reading of a loan nobody has declared.

        Writes nothing. An HCSF breach is reported, never refused (§15, §17).

        Raises:
            MortgageFeesExceedPrincipalError: the fees are not smaller than the principal.
            MortgageNonAmortizingError: the instalment does not repay the principal.
        """
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
            available = max(HCSF_LIMIT_BPS * income // _BPS_PER_UNIT - existing_charge, 0)
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
                within_ratio=None if debt_ratio is None else debt_ratio <= HCSF_LIMIT_BPS,
                within_term=data.term_months <= HCSF_MAX_TERM_MONTHS,
                limit_bps=HCSF_LIMIT_BPS,
                max_term_months=HCSF_MAX_TERM_MONTHS,
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
