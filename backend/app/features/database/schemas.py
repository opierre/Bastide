"""Response schemas for the database feature."""

from datetime import datetime

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
    investments: int


class DatabaseSummary(BaseModel):
    """The profile's data as it stands: the reset confirmation lists its counts, and the restore
    confirmation sets it beside an archive's manifest as the « Actuel » column."""

    #: The running backend's version, spelled as an archive's manifest records it.
    app_version: str
    #: When the newest import ran; `None` for a profile that never imported.
    last_import_at: datetime | None
    counts: DatabaseCounts
