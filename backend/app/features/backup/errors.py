"""Domain errors a backup inspect/restore can raise. Each code has a localized frontend message."""

from app.core.errors import ConflictError, ValidationError


class BackupInvalidError(ValidationError):
    """The file is not a FinStride backup, or its contents do not hold together."""

    code = "BACKUP_INVALID"


class BackupTooNewError(ValidationError):
    """The archive was written by a newer format than this build reads."""

    code = "BACKUP_TOO_NEW"


class BackupCurrencyMismatchError(ValidationError):
    """The archive's currency differs from the user's, which Phase 1 cannot represent."""

    code = "BACKUP_CURRENCY_MISMATCH"


class BackupRunActiveError(ConflictError):
    """A categorisation run is still writing to the data a restore would replace."""

    code = "BACKUP_RUN_ACTIVE"


class BackupConflictError(ConflictError):
    """The archive's rows collide with rows another user already owns in this database."""

    code = "BACKUP_CONFLICT"
