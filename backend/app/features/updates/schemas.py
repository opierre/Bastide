"""Response schema for the update check."""

from datetime import datetime

from pydantic import BaseModel


class UpdateStatus(BaseModel):
    """What Settings › About shows about updates.

    Always a 200: the check being off, or GitHub being out of reach, are normal states the
    screen reports, not errors.
    """

    enabled: bool
    current_version: str
    #: The newest published release the last successful check found; null before any.
    latest_version: str | None = None
    update_available: bool = False
    #: The release page to download from, set only when `update_available`.
    release_url: str | None = None
    #: When GitHub last answered.
    checked_at: datetime | None = None
    #: False when this check was due and GitHub could not be reached; what was found
    #: earlier, if anything, is still reported.
    reachable: bool = True
