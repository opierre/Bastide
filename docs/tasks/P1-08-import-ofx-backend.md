# P1-08 — Import backend: OFX/QFX
Scope: backend
Depends on: P1-06
Skills: ofx-csv-import, database, fastapi-backend, testing
PROJECT.md: §4, §5, §6

## Objective
Import OFX/QFX files into the canonical transaction model: parse → normalize → dedup → persist
atomically, recording an `import_batch` with coverage window and counts, and updating the account
balance cache. Idempotent on re-import.

## Files
- `backend/app/features/imports/{router,schemas,service,repository}.py`
- `backend/app/features/imports/parsers/ofx.py` — OFX 1.x SGML **and** OFX 2.x XML; QFX tolerated.
- `backend/app/features/imports/canonical.py` — the canonical transaction dataclass + normalize
  (description_clean, merchant attempt, signed amount_minor, dedup_hash).
- `backend/tests/features/imports/test_ofx.py` + fixtures in `tests/fixtures/imports/`.

## Contract slice
```
POST /api/v1/imports   multipart: file + account_id → 201 import_batch
GET  /api/v1/imports                                → [import_batch]   (history)
GET  /api/v1/imports/{id}                           → import_batch
```
`import_batch`: source_format, file_name, file_hash, period_start/end, transaction_count,
new_count, duplicate_count, status, error_message?.

## Steps
1. Accept upload + account_id (user-scoped). Compute `file_hash`; if already imported for this
   account → return existing batch, insert nothing.
2. `parsers/ofx.py`: parse `STMTTRN` → canonical (DTPOSTED, TRNAMT signed, FITID, NAME/MEMO,
   currency, account id). Handle Latin-1/encoding; tolerate SGML.
3. Normalize via `canonical.py`; compute `dedup_hash` for rows lacking FITID.
4. Dedup against existing rows ((account_id,fitid) else (account_id,dedup_hash)); mark duplicates.
5. Persist new rows + the batch **atomically** (one DB transaction). Derive period_start/end.
   Update `cached_balance_minor` by the summed delta (reuse P1-06 balance helper); write a
   monthly snapshot if a month boundary is crossed.
6. On parse failure: write a `failed` batch with `error_message`, insert no rows.

## Acceptance
- OFX SGML and XML both parse; QFX tolerated.
- Re-importing the same file inserts zero rows and reports duplicates.
- Signs and minor-unit conversion correct; encoding handled.
- Batch records accurate counts + coverage window; failures recorded, never partial inserts.
- Balance cache reflects imported rows.

## Tests
- `test_ofx.py` against fixtures (SGML, XML, Latin-1, QFX): correct canonical output; dedup on
  re-import; idempotent same-file import; failed-parse path records a failed batch with no rows.

## Commits
- `feat(imports): add canonical transaction model and normalization`
- `feat(imports): add OFX/QFX parser`
- `feat(imports): add import endpoint with dedup, batch history, and balance update`
