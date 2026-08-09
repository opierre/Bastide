# PROJECT.md — Personal Finance Manager

> Canonical reference for the whole project. Every `SKILL.md`, agent task card, and
> design prompt points back here. Keep this file authoritative: if a decision changes,
> change it here first, then propagate. Optimised for agent consumption — dense, no fluff.

---

## 1. Vision

A desktop-first (Flutter) personal finance application for French users first, English second.
The user imports bank data via OFX/QFX/CSV files (no direct bank connections), and the app
gives them a clear, encouraging view of their money: transactions, monthly income/expense
with month-over-month trend, categories, subscriptions, savings rate, goals, mortgages, and
French tax estimation. Transactions are auto-categorised by a local model (Ollama), with a
human-in-the-loop confirmation queue for uncertain guesses.

**Local-first, privacy-first.** All data and AI run on the user's machine. The architecture is
built so an optional cloud-sync / multi-user tier can be added later without rewrites.

---

## 2. Phased roadmap

Build in phases. Each phase ships something usable. **Phase 1 is the current build target**
and is specified in detail below; later phases are outlined and will be detailed when reached.

| Phase | Scope | Status |
|-------|-------|--------|
| **1** | Auth (register/login, locale + currency at registration); multi-account; OFX/QFX/CSV import normalised to a canonical schema + import history; transaction list; **rules-based** categorisation; dashboard (monthly income/expense, MoM trend, savings rate, by-category breakdown). | **TARGET** |
| 2 | SLM categorisation (Ollama) + confidence threshold + review/confirm queue; category management; subscription/recurring detection; savings goals (virtual envelopes). | Planned |
| 3 | Mortgages (amortisation table, debt ratio); French tax estimation (IR + IFI + capital gains/dividends/property — estimation-first); new-mortgage projection simulator. | Planned |
| 4 | Multi-user; optional cloud sync (move datastore to PostgreSQL); per-account multi-currency monitoring with FX. | Planned |

**Deferred by explicit decision (do not build in Phase 1):**
- Multi-currency accounts and FX conversion. One currency per user, chosen at registration,
  applied to all accounts. (Schema keeps a per-account `currency` column for future use.)
- AI categorisation (Phase 2). Phase 1 uses the deterministic rule engine only; unmatched
  transactions stay `uncategorized` and `needs_review = true`.

---

## 3. Architecture

```
┌──────────────────────────────┐        HTTP (localhost only)        ┌──────────────────────────────┐
│  Flutter Desktop (frontend)  │ ─────────────────────────────────▶ │   FastAPI sidecar (backend)   │
│  feature-first, Riverpod     │ ◀───────────────────────────────── │   Python 3.14, uv             │
│  i18n (ARB, fr/en)           │            JSON / REST              │   SQLAlchemy + Alembic        │
└──────────────────────────────┘                                    │            │                  │
                                                                     │            ▼                  │
                                                                     │   SQLite (WAL)  ──► Postgres  │
                                                                     │   (Phase 4 cloud tier)        │
                                                                     │            │                  │
                                                                     │            ▼                  │
                                                                     │   Ollama (Phase 2, optional)  │
                                                                     └──────────────────────────────┘
```

- **Coupling:** the Python backend runs as a **local sidecar process** the Flutter app launches
  and supervises, exposing FastAPI on `127.0.0.1` (loopback only — never bind `0.0.0.0`).
- **Datastore:** SQLite in WAL mode for the local app. Access strictly through SQLAlchemy ORM +
  Alembic migrations so the Phase 4 switch to PostgreSQL is a dialect/connection change.
- **AI (Phase 2):** Ollama, model configurable in settings, default Gemma 4 E4B. Categorisation
  degrades gracefully if Ollama is absent (rules only).
- **Modularity:** feature-first on both sides. A feature owns its routes/models/services
  (backend) and its screens/state/widgets (frontend). No cross-feature reach-through.

### Monorepo layout

```
finstride/
├── PROJECT.md                  # this file
├── CLAUDE.md                   # global agent conventions
├── .claude/
│   ├── settings.json           # shared Claude Code config
│   └── skills/                 # the SKILL.md set
├── docs/
│   ├── tasks/                  # atomic task cards (one feature/slice each)
│   └── design/                 # design-system block + Stitch/Claude Design prompts
├── backend/
│   ├── CLAUDE.md               # Python/FastAPI rules
│   ├── pyproject.toml          # uv-managed
│   ├── app/
│   │   ├── core/               # config, db session, security, errors
│   │   ├── features/           # auth/ accounts/ imports/ transactions/ categories/ rules/ dashboard/
│   │   └── main.py
│   ├── migrations/             # Alembic
│   └── tests/                  # pytest, mocks
├── frontend/
│   ├── CLAUDE.md               # Flutter/Dart rules
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── core/               # theme, router, api client, l10n
│   │   ├── features/           # auth/ accounts/ imports/ transactions/ categories/ dashboard/
│   │   └── main.dart
│   ├── l10n/                   # app_en.arb, app_fr.arb
│   └── test/
├── docker-compose.yml          # dev only
└── README.md
```

Each `feature/` folder is a vertical slice. A package without its own `CLAUDE.md` inherits the
root one; `backend/CLAUDE.md` and `frontend/CLAUDE.md` add stack-specific rules.

---

## 4. Data model (Phase 1)

All money is stored as **signed integer minor units** (e.g. cents) plus an ISO-4217 `currency`
code. Negative `amount_minor` = outflow/expense, positive = inflow/income. **Never use floats
for money.** Primary keys are UUIDs (string). Timestamps are UTC ISO-8601.

### `users`
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| email | text unique | |
| password_hash | text | Argon2id |
| display_name | text | |
| locale | text | `'fr'` \| `'en'` |
| currency | text | ISO-4217, applies to all accounts (Phase 1) |
| created_at / updated_at | datetime | |

### `accounts`
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK → users | |
| name | text | user-facing label |
| type | text | `checking` \| `savings` \| `credit` \| `deferred_card` \| `cash` \| `other` (`deferred_card` = the holding account a deferred-debit card posts to, settled monthly against the current account) |
| institution | text | bank name (drives brand-logo lookup) |
| currency | text | defaults to `users.currency`; reserved for future multi-currency |
| ofx_account_id | text null | bank's account id (OFX `ACCTID`), used for import routing; unique per user where set |
| opening_balance_minor | int | |
| archived | bool | default false |
| cached_balance_minor | int | maintained incrementally; see note |
| created_at / updated_at | datetime | |

> **Balance strategy — authoritative ledger, fast reads.** The transaction ledger is the single
> source of truth; the balance is *derived* from it so it can never silently drift. But it is
> **not** recomputed with a full `SUM()` on every read:
> - `cached_balance_minor` is updated by a **delta** on each insert/edit/delete (`new = old ± amount`),
>   so normal reads are O(1).
> - **Monthly balance snapshots** per account let any point-in-time balance be computed as
>   `nearest snapshot + sum(rows since)` — a few recent rows, never the whole history.
> - A **full recompute** exists only as a reconciliation/repair job (post-import integrity check
>   or a manual "recalculate" action). If a fresh recompute ever disagrees with the cache, that
>   is a detectable bug — which is the safety the derived model buys us.
>
> **`opening_balance_minor` is the seed, and an OFX import corrects it.** It means "what the
> account held before its first transaction" — a figure no user can look up, so asked directly
> they type today's balance instead and every imported row is then counted twice. On an
> account's **first** OFX import we therefore derive it from the statement's `LEDGERBAL`:
> `opening = BALAMT − sum(rows booked on or before DTASOF)`. Only the first: a later
> statement's balance is equally true, but re-deriving from it would absorb any un-imported
> gap in the ledger into the opening balance rather than surfacing it. CSV carries no declared
> balance, so a CSV-only account keeps the figure the user typed.
>
> **Every import after the first compares instead of correcting.** Its statement's `LEDGERBAL`
> is checked against what the ledger implies at that date (`point_in_time_balance`); a
> disagreement is recorded on the `import_batch` as `balance_mismatch_minor` /
> `balance_mismatch_as_of` rather than silently absorbed — it means a missed statement, an
> un-imported gap, or a bad earlier correction, and the user needs to see it to act on it.
>
> **`opening_balance_minor` is also user-patchable** (`PATCH /accounts/{id}`), the manual
> counterpart to the two mechanisms above — for a CSV-only account (no `LEDGERBAL` ever), or to
> fix a bad first derivation. The patch goes through `shift_opening_balance`, which moves
> `cached_balance_minor` **and every existing snapshot** by the same delta rather than
> recomputing them independently — the ledger didn't change, so nothing derived from it should
> move by anything other than exactly that delta.
>
> (Scale note: a single user's ledger is realistically tens of thousands of rows, not millions;
> even a naive indexed `SUM(account_id)` would be sub-millisecond. The cache + snapshots keep it
> fast regardless.)

### `transactions`
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| account_id | uuid FK → accounts | |
| import_batch_id | uuid FK → import_batches | |
| booked_date | date | |
| value_date | date null | |
| amount_minor | int | signed |
| currency | text | = account currency (Phase 1) |
| description_raw | text | as received from file |
| description_clean | text | normalised for matching/display |
| memo | text null | bank free-text detail (OFX `MEMO`), display only |
| merchant | text null | extracted if possible |
| category_id | uuid FK → categories null | |
| categorization_source | text | `rule` \| `model` \| `user` \| `uncategorized` |
| categorization_confidence | real null | model only (Phase 2) |
| needs_review | bool | true until confirmed/assigned with confidence |
| fitid | text null | OFX unique id, used for dedup |
| dedup_hash | text | stable hash for CSV dedup (see §6) |
| created_at / updated_at | datetime | |

Unique constraint to prevent duplicate imports: `(account_id, fitid)` when `fitid` present,
else `(account_id, dedup_hash)`.

### `categories`
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK null | null = system default |
| parent_id | uuid FK → categories null | subcategories |
| name | text | display name (system categories use i18n keys) |
| kind | text | `income` \| `expense` \| `transfer` |
| icon | text | icon identifier |
| color | text | hex |
| is_system | bool | |

Ship a **rich default set (~25+) of system categories**, organised into parent groups with
subcategories (e.g. Housing → Rent/Mortgage, Utilities; Food → Groceries, Restaurants; Transport
→ Fuel, Public transit, Parking; Income → Salary, Refunds; etc.), seeded localised (fr/en). The
richer label space also benefits the Phase 2 SLM.

### `categorization_rules`
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK → users | |
| priority | int | lower = evaluated first |
| match_field | text | `description_clean` \| `merchant` \| `amount` |
| match_type | text | `contains` \| `equals` \| `regex` \| `range` |
| pattern | text | term, regex, or `min:max` for amount range |
| category_id | uuid FK → categories | |
| enabled | bool | |
| created_at | datetime | |

### `import_batches`
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK | |
| account_id | uuid FK | |
| source_format | text | `ofx` \| `qfx` \| `csv` |
| file_name | text | |
| file_hash | text | reject re-import of identical file |
| period_start / period_end | date | coverage window, derived from contents |
| transaction_count / new_count / duplicate_count | int | |
| status | text | `success` \| `partial` \| `failed` |
| error_message | text null | |
| balance_mismatch_minor | int null | declared `LEDGERBAL` − ledger-implied balance; set only from the account's 2nd+ import, and only when non-zero |
| balance_mismatch_as_of | date null | the date the mismatch above holds at |
| imported_at | datetime | |

### `csv_templates` (per-bank CSV mapping, saved once and reused)
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK | |
| bank_name | text | |
| delimiter | text | e.g. `;` |
| encoding | text | e.g. `latin-1`, `utf-8` |
| date_format | text | e.g. `%d/%m/%Y` |
| decimal_separator | text | `,` or `.` |
| amount_strategy | text | `signed` \| `debit_credit` |
| column_map | json | maps canonical fields → CSV column names/indices |
| created_at | datetime | |

### `account_balance_snapshots`
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| account_id | uuid FK → accounts | |
| period_end | date | the closing date this snapshot represents (e.g. month-end) |
| balance_minor | int | account balance as of `period_end` |
| created_at | datetime | |

> Supports the balance strategy above: any point-in-time balance = nearest snapshot with
> `period_end ≤ date` + sum of rows after it, bounding every historical query to a small row
> count. Snapshots are written/updated on import when a period boundary is crossed and can be
> rebuilt by the reconciliation routine. Unique on `(account_id, period_end)`.

**Phase 2+ entities (stubs, do not build now):** `goals`, `goal_allocations`, `mortgages`,
`amortization_entries`, `tax_profiles`, `projections`.

---

## 5. API contract (Phase 1)

REST/JSON, all under `/api/v1`. Auth via bearer token (opaque or JWT; see §8). All endpoints
are user-scoped — a user only ever sees their own rows.

> **Why REST, not GraphQL.** GraphQL's wins (client-chosen fields, collapsing many resources
> into one round trip) require many heterogeneous remote clients and network latency to pay off.
> This app has one client (the Flutter app we control) talking to a **loopback sidecar** where
> round-trip cost is ~0, so those wins are moot — while GraphQL would add N+1/dataloader
> complexity, weaker caching, and awkward multipart uploads (our OFX/CSV import). FastAPI + REST
> gives typed Pydantic I/O, auto OpenAPI docs, and trivial uploads. The one composite view
> (dashboard) is served by a single purpose-built endpoint. Revisit only if a Phase 4 cloud tier
> grows multiple external client types.

```
POST   /auth/register        {email,password,display_name,locale,currency} → {token,user}
POST   /auth/login           {email,password} → {token,user}
POST   /auth/logout
GET    /auth/me              → {user}

GET    /accounts            → [account]   (?ofx_account_id=… → the 0–1 account holding it)
POST   /accounts            {name,type,institution,opening_balance_minor[,ofx_account_id]} → account
GET    /accounts/{id}       → account (with derived current balance)
PATCH  /accounts/{id}
DELETE /accounts/{id}        (archive, not hard delete)

GET    /banks               ?bank_code=… → [bank]  (0–1: the French bank code resolved to its bank)

POST   /imports             multipart: file + account_id [+ csv_template_id] → import_batch
GET    /imports             → [import_batch]            (history)
GET    /imports/{id}        → import_batch
POST   /csv-templates       {…mapping…} → csv_template
GET    /csv-templates       → [csv_template]

GET    /transactions        ?account_id&from&to&category_id&needs_review&q&page → page<transaction>
GET    /transactions/{id}   → transaction
PATCH  /transactions/{id}   {category_id|description_clean|merchant} (sets source=user)

GET    /categories          → [category]   (system + user, localised)
POST   /categories          {name,kind,parent_id,icon,color} → category
PATCH  /categories/{id}
DELETE /categories/{id}

GET    /rules               → [rule]
POST   /rules               {…} → rule
PATCH  /rules/{id}
DELETE /rules/{id}
POST   /rules/apply         {account_id?} → {recategorized_count}   (re-run rules)

GET    /dashboard/summary   ?month=YYYY-MM → {
          income_minor, expense_minor, net_minor, savings_rate,
          income_delta_pct, expense_delta_pct, net_delta_pct, savings_rate_delta_pct,  // vs prev.
          by_category: [{category_id, name, amount_minor, pct}],
          currency
        }
GET    /dashboard/trends    → {                          // no month param — see below
          monthly_series: [{month, income_minor, expense_minor, net_minor}],   // last 4 months
          savings_series: [{month, cumulative_minor}],                         // last 6 months
          currency
        }
```

> **Why `/dashboard/trends` is separate from `/dashboard/summary`.** The summary answers "how
> did *this month* go" and is driven by the panel's month picker. The two trend series answer
> "how am I trending lately", whose window ends at the *current* month and does not move when
> the user pages back to inspect an older one. Folding them into `/summary` would mean an
> endpoint whose response is only partly about the `month` it was asked for, and re-computing
> identical series on every month change. Kept separate, the trends are fetched once and
> survive month changes.

Errors: consistent JSON envelope `{error: {code, message, details?}}` with proper HTTP status.

---

## 6. Import pipeline

One **canonical transaction model** is the target of every parser. The rest of the app never
knows the source format.

1. **Validate file** — reject if `file_hash` already imported for this account.
2. **Parse to canonical** —
   - **OFX/QFX:** parse `STMTTRN` records; use `FITID` as the dedup key; read currency and
     account id; derive `period_start/end` from transaction date range.
   - **CSV:** require a `csv_template` (created via a one-time per-bank column-mapping UI).
     Handle French realities: `;` delimiters, `,` decimals, `%d/%m/%Y` dates, Latin-1/UTF-8,
     and either signed amounts or separate debit/credit columns.
3. **Normalise** — clean description (`description_clean`), attempt `merchant` extraction,
   compute `amount_minor` (signed), set `currency` = account currency.
4. **Dedup** — `fitid` if present, else `dedup_hash = hash(account_id, booked_date,
   amount_minor, normalised description)`. Mark duplicates, don't insert them.
5. **Categorise** — run the rule engine (§7). Phase 2 adds the model step.
6. **Persist** — insert new transactions in one transaction batch; write `import_batch` with
   counts and coverage window.

---

## 7. Categorisation pipeline

**Phase 1 (rules only):**
- Evaluate enabled rules ordered by `priority` (ascending). First match wins.
- On match: set `category_id`, `categorization_source = rule`, `needs_review = false`.
- No match: `category_id = null`, `source = uncategorized`, `needs_review = true`.
- `POST /rules/apply` re-runs rules over existing transactions (e.g. after adding a rule),
  but **never overrides** a transaction whose `source = user`.

**Phase 2 (adds the model, designed now so Phase 1 doesn't block it):**
- Unmatched transactions go to the SLM (Ollama) with a prompt containing the category list +
  cleaned description/merchant + a few-shot set.
- If returned `confidence ≥ threshold` (default 0.80, configurable): assign,
  `source = model`, `needs_review = false`. Else `needs_review = true`.
- User confirms/corrects in the review queue. A user correction may offer "always categorise
  X as Y" → creates a `categorization_rule` (the system learns cheaply and deterministically).

This is the small-model-with-deferral pattern: the cheap path handles the easy majority and
only genuinely uncertain items reach the human.

---

## 8. Cross-cutting standards

**Auth / security (local-first):**
- Passwords hashed with **Argon2id**. Token returned on login (opaque token in a local store
  is fine for Phase 1; JWT acceptable). Backend binds loopback only.
- Future cloud tier (Phase 4) reuses the same auth surface with real session management.

**i18n / l10n (day one):**
- Frontend: `flutter_localizations` + `intl`, ARB files `app_fr.arb` / `app_en.arb`. No
  hard-coded user-facing strings. Locale chosen at registration, switchable in settings.
- Dates, numbers, and currency formatted per locale (`fr_FR` uses `1 234,56 €`).
- System categories seeded with localised names.

**Money & currency:** integer minor units + ISO-4217 everywhere; one currency per user
(Phase 1); per-account `currency` column reserved for Phase 4.

**Testing:**
- Backend: `pytest`. Unit tests mock the DB session, file I/O, and (Phase 2) Ollama — no live
  external dependencies in unit tests. Integration tests may use a temp SQLite file.
- Frontend: `flutter_test` + `mocktail`. Widget tests for screens, unit tests for state/services.
- Every feature slice ships with tests. CI runs lints + tests.

**Commits:** Conventional Commits — `type(scope): subject` where type ∈
`feat|fix|docs|refactor|test|chore|build|ci`. One logical change per commit. Scope = feature
name (e.g. `feat(imports): parse OFX STMTTRN records`). This enables clean rollback.

**Code style:**
- Python: full type hints, **`ruff` (lint + format)** and **`ty` (type checking)** — no `black`
  (ruff's formatter replaces it) and no `mypy` in the normal loop. Pydantic v2 models for I/O,
  Google-style docstrings. Services are pure-ish and unit-testable; routes are thin.
- Dart: `flutter_lints`/`effective_dart`, Riverpod for state, immutable models, no business
  logic in widgets.
- Human-readable, documented code. Comments explain *why*, not *what*.

---

## 9. Design system (summary; full tokens live in `design-system` skill)

- **Dark mode first.** Coherent palette across all panels.
- **Modern, readable type:** Open Sans (Google Fonts) for UI text.
- **Modern icons;** big-brand logos integrated where a merchant/institution has one, with a
  generated monogram fallback when no logo is available.
- **Fixed chrome:** the navbar, top bar, and bottom bar keep the same position and behaviour on
  every panel. Layout invariants are non-negotiable across screens.
- **Encouraging UX:** the dashboard leads with progress and trend, nudging the user to keep
  tracking. Savings rate is a first-class, always-visible metric.

---

## 10. Tech versions

Pinned intent (verify exact patch at install time and record in lockfiles):

- Python 3.14 · FastAPI · Pydantic v2 · SQLAlchemy 2.x · Alembic · **uv** (env + deps)
- Tooling: **ruff** (lint + format) · **ty** (Astral type checker, primary in CI + editor).
  `ty` is beta with a stable release targeted for 2026; its Pydantic inference is still
  maturing, so `mypy --strict` is kept only as an optional per-file escape hatch, not part of
  the normal loop. No `black`.
- SQLite (WAL) now · PostgreSQL 18.x (Phase 4)
- Flutter (latest stable) · Dart · Riverpod · intl · flutter_localizations
- Ollama (latest) · default model **Gemma 4 E4B** (configurable), optional finance-tuned 8B
  model for the Phase 2+ insights feature
- Docker (dev) · native installers (release)

---

## 11. Definition of done (per feature slice)

A slice is done when: it matches this spec; has passing unit tests with external deps mocked;
passes lints; ships UI strings in both `fr` and `en`; money is integer minor units; and the
work lands as one or more Conventional Commits.
