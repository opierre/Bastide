"""Response schemas for the backup feature."""

from datetime import datetime

from pydantic import BaseModel


class BackupCounts(BaseModel):
    """What an archive holds, in the terms the restore confirmation lists."""

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
    #: The user's own tax brackets and parameters together — overrides of the official values.
    tax_overrides: int


class BackupSummary(BaseModel):
    """An archive's manifest: returned by inspect and restore, and sent with an export."""

    format_version: int
    app_version: str
    exported_at: datetime
    currency: str
    counts: BackupCounts
