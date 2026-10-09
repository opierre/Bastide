"""Full export and restore of everything one user owns."""

from collections.abc import Callable
from datetime import UTC, date, datetime
from typing import Any

from sqlalchemy.exc import IntegrityError

from app import __version__
from app.features.auth.models import User
from app.features.backup.archive import (
    FORMAT_MARKER,
    FORMAT_VERSION,
    TABLE_SINCE_VERSION,
    ArchiveReader,
    write_archive,
)
from app.features.backup.errors import (
    BackupConflictError,
    BackupCurrencyMismatchError,
    BackupInvalidError,
    BackupRunActiveError,
    BackupTooNewError,
)
from app.features.backup.repository import (
    BACKUP_TABLES,
    BackupRepository,
    ColumnSpec,
    describe,
)
from app.features.backup.schemas import BackupCounts, BackupSummary
from app.features.settings.service import SettingsService

# Rows the restore buffers before inserting, so a large table never sits in memory whole.
_RESTORE_BATCH = 500


class BackupService:
    """Builds `.bastide` archives and replaces a user's data with one."""

    def __init__(
        self,
        repository: BackupRepository,
        settings_service: SettingsService,
        clock: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self._repository = repository
        self._settings = settings_service
        self._clock = clock

    def export(self, user: User) -> tuple[bytes, BackupSummary]:
        """Archive every row the user owns and stamp the time as their latest backup."""
        # Materialised first so every archive carries a settings row to restore.
        self._settings.get_or_create(user.id)
        exported_at = self._clock()
        manifest = {
            "format": FORMAT_MARKER,
            "format_version": FORMAT_VERSION,
            "app_version": __version__,
            "exported_at": exported_at.isoformat(),
            "currency": user.currency,
        }
        content = write_archive(
            manifest,
            ((name, self._repository.iter_rows(name, user.id)) for name in BACKUP_TABLES),
        )
        # Stamped after the archive exists, so a failed build never reports a backup.
        self._settings.record_backup(user.id, exported_at)
        return content, self._summary(ArchiveReader(content).manifest())

    def inspect(self, user: User, content: bytes) -> BackupSummary:
        """Report what an archive holds, refusing one this build or this user cannot restore.

        Raises:
            BackupInvalidError: not a Bastide archive, or its manifest is malformed.
            BackupTooNewError: written by a newer archive format.
            BackupCurrencyMismatchError: its currency is not the user's.
        """
        return self._summary(self._checked_manifest(ArchiveReader(content), user))

    def restore(self, user: User, content: bytes) -> BackupSummary:
        """Replace all of the user's data with the archive's, atomically.

        Every check that can be made without writing is made first; the rest happen row by row
        inside one transaction that is rolled back whole on the first failure, so a refused
        archive leaves the user's data exactly as it was.

        Raises:
            BackupInvalidError / BackupTooNewError / BackupCurrencyMismatchError: as `inspect`,
                plus malformed rows and references to rows the archive does not hold.
            BackupRunActiveError: a categorisation run is still writing to this data.
            BackupConflictError: the archive's rows collide with another user's.
        """
        reader = ArchiveReader(content)
        manifest = self._checked_manifest(reader, user)
        if self._repository.has_active_run(user.id):
            raise BackupRunActiveError("A categorisation run is in progress.")
        # The time of the latest backup is a fact about this install, not about the archive.
        last_backup_at = self._settings.get_or_create(user.id).last_backup_at

        try:
            self._repository.delete_user_data(user.id)
            known: dict[str, set[str]] = {"categories": self._repository.system_category_ids()}
            for name in BACKUP_TABLES:
                if manifest["format_version"] < TABLE_SINCE_VERSION.get(name, 1):
                    continue  # the archive predates this table: it has nothing to restore
                specs = describe(name)
                batch: list[dict[str, Any]] = []
                for raw in reader.rows(name):
                    row = self._decode_row(name, specs, raw, user.id, known)
                    if name == "user_settings":
                        row["last_backup_at"] = last_backup_at
                    batch.append(row)
                    if len(batch) >= _RESTORE_BATCH:
                        self._repository.insert_rows(name, batch)
                        batch = []
                self._repository.insert_rows(name, batch)
            self._repository.commit()
        except IntegrityError as exc:
            self._repository.rollback()
            raise BackupConflictError("The backup conflicts with existing data.") from exc
        except BaseException:
            self._repository.rollback()
            raise
        return self._summary(manifest)

    def _checked_manifest(self, reader: ArchiveReader, user: User) -> dict[str, Any]:
        manifest = reader.manifest()
        format_version = manifest.get("format_version")
        if not isinstance(format_version, int) or format_version < 1:
            raise BackupInvalidError("The backup's format version is malformed.")
        # Checked before anything else about the contents: a newer format may have changed
        # exactly the fields the checks below would read.
        if format_version > FORMAT_VERSION:
            raise BackupTooNewError(
                "The backup comes from a newer version of Bastide.",
                details={"format_version": format_version, "supported": FORMAT_VERSION},
            )
        currency = manifest.get("currency")
        if not isinstance(currency, str):
            raise BackupInvalidError("The backup has no currency.")
        if currency.upper() != user.currency.upper():
            raise BackupCurrencyMismatchError(
                "The backup uses a different currency.",
                details={"backup_currency": currency, "user_currency": user.currency},
            )
        self._summary(manifest)  # validates the remaining fields
        return manifest

    @staticmethod
    def _summary(manifest: dict[str, Any]) -> BackupSummary:
        tables = manifest.get("tables")
        if not isinstance(tables, dict):
            raise BackupInvalidError("The backup's manifest has no table counts.")
        try:
            return BackupSummary(
                format_version=manifest["format_version"],
                app_version=manifest["app_version"],
                exported_at=manifest["exported_at"],
                currency=manifest["currency"],
                counts=BackupCounts(
                    accounts=tables.get("accounts", 0),
                    transactions=tables.get("transactions", 0),
                    categories=tables.get("categories", 0),
                    rules=tables.get("categorization_rules", 0),
                    recurring=tables.get("recurring_series", 0),
                    goals=tables.get("goals", 0),
                    # Absent from a format-1 manifest, which predates these tables.
                    mortgages=tables.get("mortgages", 0),
                    properties=tables.get("properties", 0),
                    simulations=tables.get("mortgage_simulations", 0),
                ),
            )
        except (KeyError, TypeError, ValueError) as exc:
            raise BackupInvalidError("The backup's manifest is malformed.") from exc

    @staticmethod
    def _decode_row(
        name: str,
        specs: list[ColumnSpec],
        raw: Any,
        user_id: str,
        known: dict[str, set[str]],
    ) -> dict[str, Any]:
        """Turn one archived line into an insertable row owned by `user_id`.

        Every foreign key must point at a row already restored from this archive (or, for
        categories, at a system category). That is what keeps a crafted file from attaching
        rows to someone else's account.
        """
        if not isinstance(raw, dict):
            raise BackupInvalidError(f"A {name} row is malformed.")
        row: dict[str, Any] = {}
        for spec in specs:
            value = raw.get(spec.name)
            if value is None:
                if not spec.nullable:
                    raise BackupInvalidError(f"A {name} row is missing {spec.name}.")
                row[spec.name] = None
                continue
            value = _decode_value(name, spec, value)
            if spec.references == "users":
                value = user_id
            elif spec.references is not None and value not in known.get(spec.references, ()):
                raise BackupInvalidError(f"A {name} row references a missing {spec.references}.")
            row[spec.name] = value

        if name == "categorization_runs" and row["status"] in ("pending", "running"):
            # Its executor is gone; left in flight it would block every future run.
            row["status"] = "failed"
        known.setdefault(name, set()).add(row["id"])
        return row


def _decode_value(table: str, spec: ColumnSpec, value: Any) -> Any:
    kind = spec.python_type
    try:
        if kind is datetime:
            return datetime.fromisoformat(value)
        if kind is date:
            return date.fromisoformat(value)
    except (TypeError, ValueError) as exc:
        raise BackupInvalidError(f"A {table} row has an invalid {spec.name}.") from exc
    # `bool` is an `int`, so a boolean in an integer column (money, above all) is refused
    # explicitly; a float column accepts an integer JSON value.
    valid = (
        isinstance(value, bool)
        if kind is bool
        else isinstance(value, int | float) and not isinstance(value, bool)
        if kind is float
        else isinstance(value, kind) and not isinstance(value, bool)
    )
    if not valid:
        raise BackupInvalidError(f"A {table} row has an invalid {spec.name}.")
    return value
