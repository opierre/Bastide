# P1-09 — Import backend: CSV templates
Scope: backend
Depends on: P1-08
Skills: ofx-csv-import, database, fastapi-backend, testing
PROJECT.md: §4, §5, §6

## Objective
Support CSV import via reusable per-bank `csv_template`s, handling French CSV realities, feeding
the same canonical pipeline (normalize → dedup → persist) built in P1-08.

## Files
- `backend/app/features/imports/parsers/csv.py` — template-driven CSV → canonical.
- Extend `imports/{router,schemas,service,repository}.py` for csv_template CRUD + CSV import path.
- `backend/tests/features/imports/test_csv.py` + CSV fixtures.

## Contract slice
```
POST /api/v1/csv-templates  {bank_name,delimiter,encoding,date_format,decimal_separator,
                             amount_strategy,column_map,header_offset} → 201 csv_template
GET  /api/v1/csv-templates                                            → [csv_template]
POST /api/v1/imports   multipart: file + account_id + csv_template_id  → 201 import_batch
POST /api/v1/csv-templates/preview  multipart: file + (template fields) → parsed sample rows
```

## Steps
1. `parsers/csv.py`: apply a template — delimiter (often `;`), encoding (Latin-1/UTF-8 detect),
   `date_format` (e.g. `%d/%m/%Y`), decimal separator (`,`), `amount_strategy`
   (`signed` | `debit_credit`), header offset. Output canonical rows (reuse `canonical.py`).
2. Template CRUD (user-scoped). `preview` parses a few rows so the UI can validate a mapping
   before saving — does not import.
3. CSV import path: same dedup + atomic persist + batch + balance update as P1-08
   (`dedup_hash`, since CSV usually lacks FITID).
4. Validate template on create (parse sample; reject if columns unmapped/unparseable).

## Acceptance
- A saved template parses that bank's CSV correctly on subsequent imports (one-time mapping).
- Handles `;` delimiter, comma decimals, `dd/MM/yyyy`, Latin-1, and both signed and debit/credit
  amount layouts.
- Preview returns sample rows without importing.
- CSV import dedups, persists atomically, updates balance, writes a batch — same as OFX.

## Tests
- `test_csv.py` fixtures: `;`+comma-decimal signed; debit/credit columns; Latin-1 encoding;
  header offset. Assert correct signs/minor units, dedup on re-import, preview-without-import,
  invalid template rejected.

## Commits
- `feat(imports): add CSV template CRUD and preview`
- `feat(imports): add template-driven CSV parser for French bank formats`
