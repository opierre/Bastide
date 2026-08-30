---
name: ofx-csv-import
description: Use when building or changing the file import pipeline — parsing OFX/QFX (French SGML dialects, Latin-1), routing a statement to the account its own header names, normalizing to the canonical transaction model, deduplication, or the import-batch lifecycle and history. Encodes the one-canonical-model rule, FITID/dedup-hash dedup, idempotent re-import handling, and the fact that CSV import has been removed.
---

# OFX Import

Turns bank statements into canonical transactions. Source of truth: `PROJECT.md` §6. Obey
**database** (money, dedup constraints) and **architecture** (this is a feature: parsing in
services, DB in repositories).

> **CSV import was removed**, root and branch: no `csv_templates` table, no CSV parser, no
> mapping wizard, and no `csv` value anywhere in `source_format`. A CSV names no account, and the
> panel now reads the destination out of the file rather than asking for it. Do not reintroduce a
> CSV path without the user asking for it.

## The one rule

Every parser targets the **same canonical transaction model**. After parsing, no downstream code
knows or cares whether the source was OFX or QFX. Format-specific logic lives only in the
parser/adapter for that format.

Canonical fields produced per transaction (see `PROJECT.md` §4 `transactions`):
`booked_date, value_date?, amount_minor (signed), currency, description_raw,
description_clean, memo?, merchant?, fitid?, dedup_hash`.

## Pipeline (idempotent)

1. **Accept file** + `account_id`. Compute `file_hash`.
2. **Reject duplicate file**: if `file_hash` already imported for this account → return the
   existing batch info, import nothing.
3. **Parse → canonical** (per format below).
4. **Normalize**: build `description_clean` (collapse whitespace, strip bank noise/ref codes,
   uppercase-fold for matching), attempt `merchant` extraction, compute signed `amount_minor`,
   set `currency` = account currency.
5. **Dedup**: `fitid` if present else `dedup_hash`; mark duplicates, insert only new rows.
6. **Categorize**: run the rule engine (Phase 1) / + model (Phase 2). See **ai-categorization**.
7. **Persist**: insert new rows in one DB transaction; write the `import_batch` with
   `transaction_count / new_count / duplicate_count`, derived `period_start/end`, and `status`.

The whole step 7 is atomic — a failed import leaves no partial rows and a `failed` batch record
with `error_message`.

## OFX / QFX

- Parse SGML/XML `STMTTRN` records. Map: `DTPOSTED→booked_date`, `TRNAMT→amount_minor` (sign as
  given), `FITID→fitid`, `NAME→description_raw`, `MEMO→memo` (its own field — display only, so
  merchant extraction, rules, and the dedup hash read the label alone; a memo-only record puts
  the memo in `description_raw` instead), `CURDEF`/account currency, account id from
  `BANKACCTFROM`/`ACCTID` for routing.
- QFX is OFX with Quicken extras — same parser, tolerate extra tags.
- Be tolerant: some French banks emit OFX 1.x SGML (not strict XML), inconsistent casing, and
  Latin-1. Detect/handle encoding; don't assume UTF-8.
- `FITID` is the dedup key and is trusted unique per account.
- `BANKACCTFROM`/`CCACCTFROM` is read **client-side too** (`data/ofx_account_parser.dart`) to
  route the import: the panel resolves the file's account block against the user's accounts,
  imports into the match, offers to create the account when there is none, and asks only when
  the file leaves the question genuinely open (several candidates, or no readable block).

## Dedup hash

When `fitid` is absent:
`dedup_hash = stable_hash(account_id, booked_date, amount_minor, description_clean)`.
Same triple within an account = duplicate. Document that two genuinely identical transactions on
the same day (rare) may collide; acceptable trade-off, surfaced in import results so the user can
spot it.

## Import history

`import_batches` is the user-facing history: file name, source format (`ofx`/`qfx`), import
date, coverage window (`period_start/end`), and counts. Every import — success, partial, or failed — writes a
batch row. Never delete batch history on re-import; it's an audit trail.

## Testing

- Unit-test parsers against **fixture files** for each real bank dialect (OFX SGML, OFX XML,
  Latin-1 payloads). Mock file I/O.
- Assert: correct sign, correct minor-unit conversion, dedup catches re-imports, idempotent
  re-import of the same file inserts zero rows, encoding handled.
- Keep a small library of anonymized fixture files under `backend/tests/fixtures/imports/`.
