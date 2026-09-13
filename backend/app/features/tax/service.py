"""Business logic for tax profiles.

One rule shapes everything here: a profile is **created lazily and never guessed at**. The row
appears with the §4c defaults on first read, and every figure in it got there because the user
put it there.
"""

from datetime import date

from app.core.errors import ValidationError
from app.features.auth.models import User
from app.features.tax.models import TaxProfile
from app.features.tax.repository import TaxRepository
from app.features.tax.schemas import TaxProfileRead, TaxProfileUpdate


class TaxYearOutOfRangeError(ValidationError):
    """Raised when a `tax_year` path segment is outside the range the app can estimate.

    Next year's income cannot be estimated, and offering it would imply otherwise; a year older
    than the seeded parameter set has no barème to run against.
    """

    code = "TAX_YEAR_OUT_OF_RANGE"


def to_read(profile: TaxProfile, currency: str) -> TaxProfileRead:
    """The stored profile on the wire. Nothing here is derived — that is §16's job."""
    return TaxProfileRead(
        id=profile.id,
        tax_year=profile.tax_year,
        # ty: ignore[invalid-argument-type] — the column is a plain str; the Literal is enforced
        # by the update schema, which is the only writer of this field.
        household=profile.household,
        dependents_count=profile.dependents_count,
        single_parent=profile.single_parent,
        salaries_minor=profile.salaries_minor,
        pensions_minor=profile.pensions_minor,
        dividends_minor=profile.dividends_minor,
        interest_minor=profile.interest_minor,
        capital_gains_minor=profile.capital_gains_minor,
        pfu_opt_out=profile.pfu_opt_out,
        deductions_minor=profile.deductions_minor,
        credits_minor=profile.credits_minor,
        currency=currency,
        created_at=profile.created_at,
        updated_at=profile.updated_at,
    )


class TaxService:
    """Tax profile read and patch, scoped to a user."""

    def __init__(self, repository: TaxRepository) -> None:
        self._repository = repository

    def list_profiles(self, user: User) -> list[TaxProfileRead]:
        """The user's declared years, newest first. Creates nothing — a list is a list."""
        return [
            to_read(profile, user.currency) for profile in self._repository.list_profiles(user.id)
        ]

    def get_or_create(self, user: User, tax_year: int, today: date) -> TaxProfileRead:
        """Return the year's profile, creating it with the §4c defaults if absent.

        Idempotent: a second call — including one racing the first — returns the existing row
        rather than creating a second.

        Raises:
            TaxYearOutOfRangeError: the year is in the future or predates the seeded set.
        """
        return to_read(self._owned(user.id, tax_year, today), user.currency)

    def update(
        self, user: User, tax_year: int, data: TaxProfileUpdate, today: date
    ) -> TaxProfileRead:
        """Patch the supplied fields; omitted ones keep their stored value.

        The row is created first if the year has none, so the panel can declare a salary for a
        year the user has never opened without a separate call to bring it into being.

        Raises:
            TaxYearOutOfRangeError: the year is in the future or predates the seeded set.
        """
        profile = self._owned(user.id, tax_year, today)
        for field, value in data.model_dump(exclude_unset=True).items():
            if value is None:
                continue  # No column here is nullable: absent and null both mean "leave alone".
            setattr(profile, field, value)
        return to_read(self._repository.save(profile), user.currency)

    def _owned(self, user_id: str, tax_year: int, today: date) -> TaxProfile:
        """The user's profile for the year, created with defaults on first read.

        There is no cross-user read to guard here: the path carries a year, not an id, so a
        request is answered from the caller's own row or creates one.
        """
        self._check_year(tax_year, today)
        existing = self._repository.get_profile(user_id, tax_year)
        if existing is not None:
            return existing
        return self._repository.add_or_get_existing(
            TaxProfile(
                user_id=user_id,
                tax_year=tax_year,
                household="single",
                dependents_count=0,
                single_parent=False,
                salaries_minor=0,
                pensions_minor=0,
                dividends_minor=0,
                interest_minor=0,
                capital_gains_minor=0,
                pfu_opt_out=False,
                deductions_minor=0,
                credits_minor=0,
            )
        )

    def _check_year(self, tax_year: int, today: date) -> None:
        """Refuse a year the app cannot estimate, at either end.

        The floor is the oldest year the system parameter set covers: without a barème there is
        nothing to run. An install whose parameters have not been seeded at all has no floor to
        enforce — only the future check applies, rather than refusing every year on a database
        that simply has not been seeded yet.

        Raises:
            TaxYearOutOfRangeError: the year is ahead of `today` or below the seeded floor.
        """
        earliest = self._repository.earliest_seeded_tax_year()
        if tax_year > today.year or (earliest is not None and tax_year < earliest):
            raise TaxYearOutOfRangeError(
                "The tax year is outside the range this app can estimate.",
                details={"tax_year": tax_year, "earliest": earliest, "latest": today.year},
            )
