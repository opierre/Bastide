"""Domain errors a database reset can raise. Each code has a localized frontend message."""

from app.core.errors import ConflictError


class ResetRunActiveError(ConflictError):
    """A categorisation run is still writing to the data a reset would delete."""

    code = "RESET_RUN_ACTIVE"
