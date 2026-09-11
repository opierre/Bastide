"""The `.finstride` container: a ZIP holding `manifest.json` and one `<table>.jsonl` per table.

The manifest sits beside the data rather than inside it so a restore can show what a file
holds, and refuse one from a newer format, without parsing a single row. JSONL keeps each table
streamable line by line, so a long history is never one document in memory.
"""

import io
import json
import zipfile
from collections.abc import Iterable, Iterator
from typing import Any

from app.features.backup.errors import BackupInvalidError

FORMAT_MARKER = "finstride-backup"
# Bump when the archive layout or a table's columns change in a way an older build cannot read.
FORMAT_VERSION = 1
MANIFEST_NAME = "manifest.json"


def table_member(table: str) -> str:
    return f"{table}.jsonl"


def write_archive(
    manifest: dict[str, Any], tables: Iterable[tuple[str, Iterable[dict[str, Any]]]]
) -> bytes:
    """Build the archive. Fills `manifest["tables"]` with each table's row count as it writes."""
    counts: dict[str, int] = {}
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for table, rows in tables:
            count = 0
            with archive.open(table_member(table), "w") as member:
                for row in rows:
                    member.write(json.dumps(row, ensure_ascii=False).encode() + b"\n")
                    count += 1
            counts[table] = count
        # Written last because the counts are only known once every table has been streamed;
        # ZIP's central directory makes member order irrelevant to readers.
        archive.writestr(MANIFEST_NAME, json.dumps({**manifest, "tables": counts}, indent=2))
    return buffer.getvalue()


class ArchiveReader:
    """Read access to an uploaded archive. Every failure surfaces as `BackupInvalidError`."""

    def __init__(self, content: bytes) -> None:
        try:
            self._archive = zipfile.ZipFile(io.BytesIO(content))
        except zipfile.BadZipFile as exc:
            raise BackupInvalidError("The file is not a FinStride backup.") from exc

    def manifest(self) -> dict[str, Any]:
        try:
            manifest = json.loads(self._archive.read(MANIFEST_NAME))
        except (KeyError, ValueError, zipfile.BadZipFile) as exc:
            raise BackupInvalidError("The backup has no readable manifest.") from exc
        if not isinstance(manifest, dict) or manifest.get("format") != FORMAT_MARKER:
            raise BackupInvalidError("The file is not a FinStride backup.")
        return manifest

    def rows(self, table: str) -> Iterator[Any]:
        """Yield one decoded JSON value per line of the table's member."""
        try:
            with self._archive.open(table_member(table)) as member:
                for line in io.TextIOWrapper(member, encoding="utf-8"):
                    if line.strip():
                        yield json.loads(line)
        except (KeyError, ValueError, zipfile.BadZipFile) as exc:
            raise BackupInvalidError(f"The backup's {table} data is unreadable.") from exc
