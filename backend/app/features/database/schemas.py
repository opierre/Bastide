"""Response schemas for the database feature."""

from pydantic import BaseModel


class DatabaseCounts(BaseModel):
    """What a reset would delete, in the terms the confirmation modal lists.

    `categories` counts the user's own categories only: the system catalog belongs to the
    install, not to the profile, and a reset re-seeds it rather than removing it.
    """

    accounts: int
    transactions: int
    categories: int
    rules: int
    recurring: int
    goals: int
    mortgages: int
    properties: int
    simulations: int
    tax_profiles: int
    #: The user's own tax brackets and parameters together; the official system rows are the
    #: install's and survive a reset.
    tax_overrides: int


class DatabaseSummary(BaseModel):
    """The live row counts the danger zone's confirmation is built from."""

    counts: DatabaseCounts
