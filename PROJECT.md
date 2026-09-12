# PROJECT.md — Personal Finance Manager

> Canonical reference for the whole project. Every `SKILL.md`, agent task card, and
> design prompt points back here. Keep this file authoritative: if a decision changes,
> change it here first, then propagate. Optimised for agent consumption — dense, no fluff.

---

## 1. Vision

A desktop-first (Flutter) personal finance application for French users first, English second.
The user imports bank data via OFX/QFX files (no direct bank connections), and the app
gives them a clear, encouraging view of their money: transactions, monthly income/expense
with month-over-month trend, categories, subscriptions, savings rate, goals, mortgages, and
French tax estimation. Transactions are auto-categorised by a local model (Ollama), with a
human-in-the-loop confirmation queue for uncertain guesses.

**Local-first, privacy-first.** All data and AI run on the user's machine. The architecture is
built so an optional cloud-sync / multi-user tier can be added later without rewrites.

---

## 2. Phased roadmap

Build in phases. Each phase ships something usable. **Phase 3 is the current build target**;
Phases 1, 2 and 3 are specified in detail below; Phase 4 is outlined and will be detailed
when reached.

| Phase | Scope | Status |
|-------|-------|--------|
| 1 | Auth (register/login, locale + currency at registration); multi-account; OFX/QFX import normalised to a canonical schema + import history; transaction list; **rules-based** categorisation; dashboard (monthly income/expense, MoM trend, savings rate, by-category breakdown). | **Done** |
| 2 | SLM categorisation (local inference runtime) + confidence threshold + review/confirm queue; category & rule management UI; subscription/recurring detection with lifecycle; savings goals (virtual envelopes); rule packs; backup/restore. | **Done** |
| **3** | Mortgages (derived amortisation schedule, debt ratio); declared properties; French tax estimation (IR + IFI + PFU on dividends/interest/capital gains + property income — estimation-first, seeded parameters with user override); new-mortgage projection simulator; net-worth synthesis. New « Patrimoine » nav group: Crédits · Impôts · Simulateur · Synthèse. | **TARGET** |
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
                                                                     │   Local LLM runtime (Phase 2) │
                                                                     └──────────────────────────────┘
```

- **Coupling:** the Python backend runs as a **local sidecar process** the Flutter app launches
  and supervises, exposing FastAPI on `127.0.0.1` (loopback only — never bind `0.0.0.0`).
- **Datastore:** SQLite in WAL mode for the local app. Access strictly through SQLAlchemy ORM +
  Alembic migrations so the Phase 4 switch to PostgreSQL is a dialect/connection change.
- **AI (Phase 2):** a **local inference runtime**, reached over an OpenAI-compatible HTTP API on
  loopback. The backend is deliberately **runtime-agnostic**: `llama.cpp`'s `llama-server` and
  Ollama both speak that surface, so which one runs is configuration (`inference_base_url`,
  `model_tag`), not code. Default model class: Gemma 4 E4B or equivalent small multilingual
  model. Categorisation degrades gracefully when no runtime answers (rules only).

> **Why runtime-agnostic, and why the bundling call is deferred.** The two candidates differ in
> what they cost to *ship*: `llama-server` is a small per-platform binary but makes us own
> binaries, GPU-backend variants, model download, and child-process supervision; Ollama hands all
> of that over for free at the price of a separate user install. Neither difference is large next
> to the model weights (~3–4 GB for an E4B-class Q4 GGUF), which dominate any bundled delivery
> regardless of runtime — so the real packaging lever is whether weights ship at all, not which
> engine loads them. That is a Phase 3 packaging decision, made against measured installer sizes;
> Phase 2 must not prejudge it. Hence one narrow client interface and no runtime-specific calls
> anywhere above it.
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
> gap in the ledger into the opening balance rather than surfacing it. An exporter that omits
> `LEDGERBAL` declares no balance, so that account keeps the figure the user typed.
>
> **Every import after the first compares instead of correcting.** Its statement's `LEDGERBAL`
> is checked against what the ledger implies at that date (`point_in_time_balance`); a
> disagreement is recorded on the `import_batch` as `balance_mismatch_minor` /
> `balance_mismatch_as_of` rather than silently absorbed — it means a missed statement, an
> un-imported gap, or a bad earlier correction, and the user needs to see it to act on it.
>
> **`opening_balance_minor` is also user-patchable** (`PATCH /accounts/{id}`), the manual
> counterpart to the two mechanisms above — for an account whose statements never carry a
> `LEDGERBAL`, or to fix a bad first derivation. The patch goes through `shift_opening_balance`, which moves
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
| dedup_hash | text | stable hash for fitid-less dedup (see §6) |
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
| source_format | text | `ofx` \| `qfx` |
| file_name | text | |
| file_hash | text | reject re-import of identical file |
| period_start / period_end | date | coverage window, derived from contents |
| transaction_count / new_count / duplicate_count | int | |
| status | text | `success` \| `partial` \| `failed` |
| error_message | text null | |
| balance_mismatch_minor | int null | declared `LEDGERBAL` − ledger-implied balance; set only from the account's 2nd+ import, and only when non-zero |
| balance_mismatch_as_of | date null | the date the mismatch above holds at |
| imported_at | datetime | |

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

**Phase 3 entities:** specified in §4c. The stubs this section once listed are partly retired
there — `amortization_entries` and `projections` are **not** built, because both are derivable
from a handful of declared inputs (§15, §17); `mortgages` and `tax_profiles` are built as
described, joined by `properties`, `tax_brackets`, `tax_parameters` and `mortgage_simulations`.

---

## 4b. Data model (Phase 2)

Same rules as §4: UUID string PKs, UTC timestamps, money as signed integer minor units.

### `user_settings`
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK → users, unique | one row per user, created lazily on first read |
| ai_enabled | bool | default false — the user opts in |
| inference_base_url | text | OpenAI-compatible base, e.g. `http://127.0.0.1:11434/v1` (Ollama) or `http://127.0.0.1:8080/v1` (`llama-server`) |
| model_tag | text null | runtime's own model identifier; null = use whatever the runtime lists first |
| confidence_threshold | real | default `0.80`, range `[0,1]` |
| last_backup_at | datetime null | set by each full export (§14); kept across a restore |
| created_at / updated_at | datetime | |

> Server-side, not in the Flutter local store: the **backend** is what talks to the runtime, so
> the backend must own the connection settings. The frontend reads/writes them over `/settings`.

### `categorization_runs`
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK → users | |
| account_id | uuid FK → accounts null | null = all accounts |
| import_batch_id | uuid FK → import_batches null | set when the run was triggered by an import |
| trigger | text | `import` \| `manual` |
| status | text | `pending` \| `running` \| `success` \| `partial` \| `failed` \| `cancelled` |
| model_tag | text null | the model actually used, recorded for auditability |
| total_count | int | rows the run intends to process |
| processed_count | int | rows attempted so far (drives the progress UI) |
| assigned_count | int | confidence ≥ threshold → categorised |
| deferred_count | int | below threshold or unparseable reply → left for review |
| failed_count | int | rows the runtime errored on |
| error_message | text null | set on `failed` |
| started_at / finished_at | datetime null | |
| created_at | datetime | |

> Persisted rather than in-memory so a run's outcome survives a sidecar restart and the history
> is inspectable — the same reasoning as `import_batches`. A run left `running` at startup is
> reconciled to `failed` (see §7).

### `recurring_series`
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK → users | |
| account_id | uuid FK → accounts | |
| merchant_key | text | normalised grouping key derived from `merchant`/`description_clean` |
| label | text | user-facing name; defaults to the prettiest observed merchant, user-editable |
| category_id | uuid FK → categories null | |
| cadence | text | `weekly` \| `monthly` \| `quarterly` \| `yearly` \| `irregular` |
| median_interval_days | int | observed, backs the cadence classification |
| expected_amount_minor | int | signed; median of recent occurrences |
| currency | text | = account currency |
| first_seen_date / last_seen_date | date | |
| next_expected_date | date | `last_seen_date + median_interval_days` |
| occurrence_count | int | |
| status | text | `detected` \| `confirmed` \| `dismissed` \| `cancelled` |
| is_manual | bool | true = user-declared, never overwritten by the detector |
| price_change_minor | int null | last observed step in `expected_amount_minor`, signed |
| price_changed_at | date null | booked date of the occurrence that changed the price |
| created_at / updated_at | datetime | |

Unique on `(account_id, merchant_key)` for detected series, so re-running the detector updates
rather than duplicates.

### `recurring_occurrences`
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| series_id | uuid FK → recurring_series | |
| transaction_id | uuid FK → transactions, unique | a transaction belongs to at most one series |
| created_at | datetime | |

> A link table rather than a `recurring_series_id` column on `transactions`: occurrences are
> detector output that the user can attach and detach, and keeping that churn out of the ledger
> table means re-detection never writes to the single source of truth.

### `goals`
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK → users | |
| name | text | |
| target_minor | int | positive |
| currency | text | = user currency (Phase 1 rule still holds) |
| target_date | date null | |
| icon / color | text | |
| status | text | `active` \| `reached` \| `archived` |
| created_at / updated_at | datetime | |

### `goal_allocations`
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| goal_id | uuid FK → goals | |
| amount_minor | int | signed — negative = taking money back out of the envelope |
| allocated_on | date | |
| note | text null | |
| created_at | datetime | |

> **Envelopes are virtual and never touch the ledger.** `progress_minor = sum(allocations)`; a
> goal writes no transactions and moves no balance. Allocating is bookkeeping *about* money the
> user already has, so an allocation that would make the ledger and the envelopes disagree is not
> an error — over-allocation is surfaced as a warning in the UI, never blocked. See §13.

---

## 4c. Data model (Phase 3)

Same rules as §4: UUID string PKs, UTC timestamps, money as signed integer minor units. Phase 3
adds one more integer discipline: **every rate is an integer in basis points** (`_bps`, 1 bps =
0,01 %), so a 3,45 % loan is `345` and the 30 % PFU is `3000`. A rate is as unforgiving of float
drift as an amount is — 0,1 % of a 300 000 € loan over 25 years is real money — and bps keeps
every parameter, bracket and result comparable as an exact integer.

### `mortgages`
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK → users | |
| label | text | user-facing, e.g. « Résidence principale » |
| lender | text | bank name (drives the monogram chip, as `accounts.institution` does) |
| property_id | uuid FK → properties null | the asset this loan financed; null = unlinked |
| repayment_type | text | `constant_payment` (échéance constante) \| `interest_only` (in fine) |
| principal_minor | int | capital borrowed, positive |
| annual_rate_bps | int | nominal annual rate, basis points |
| insurance_monthly_minor | int | borrower's insurance premium per instalment; 0 = none |
| term_months | int | > 0 |
| first_payment_date | date | anchors every instalment date; the payment day comes from it |
| upfront_fees_minor | int | frais de dossier + garantie, default 0; feeds total cost and TAEG |
| status | text | `active` \| `repaid` \| `archived` |
| created_at / updated_at | datetime | |

> **The amortisation schedule is derived, never stored.** Five declared inputs determine every row
> of it, so persisting 300 rows per loan would create a second source of truth that an edit to the
> rate silently invalidates — the trap `cached_balance_minor` avoids by being a delta off an
> authoritative ledger (§4). Here there is no ledger to cache: the schedule *is* a pure function
> (§15), computed per request. `amortization_entries` is therefore retired, not deferred.
>
> The consequence to accept honestly: anything that breaks the closed form — an early repayment, a
> rate change, a payment holiday — cannot be expressed by these columns and is **deferred by
> decision** (§15), because supporting it means persisting loan *events* and replaying them, which
> is a different feature from the one Phase 3 promises.

### `properties`
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK → users | |
| label | text | |
| kind | text | `primary_residence` \| `rental` \| `secondary` \| `other` |
| market_value_minor | int | declared current value, positive |
| valued_on | date | when that value was declared — an estimate ages, and the UI says so |
| ownership_bps | int | the user's share, default `10000` (100 %); indivision/SCI quote-part |
| acquisition_price_minor | int null | |
| acquired_on | date null | |
| annual_rent_minor | int null | gross rent received; `rental` only |
| annual_charges_minor | int null | deductible charges; `reel` regime only |
| property_regime | text null | `micro_foncier` \| `reel`; null when not rented |
| archived | bool | default false |
| created_at / updated_at | datetime | |

> Declared, not derived: the app never sees a property in a bank statement. It exists because
> **two** Phase 3 features need it — IFI is a tax on real estate (§16) and net worth is meaningless
> without it (§18) — so it is one entity rather than a figure duplicated in each.

### `tax_profiles`
One row per user per tax year: the household facts and declared income an estimate runs on.

| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK → users | |
| tax_year | int | the year the income was earned; unique with `user_id` |
| household | text | `single` \| `couple` (marié/pacsé — one joint estimate) |
| dependents_count | int | children and dependents, default 0 |
| single_parent | bool | parent isolé (case T), default false |
| salaries_minor | int | traitements et salaires, gross annual |
| pensions_minor | int | default 0 |
| dividends_minor | int | default 0 |
| interest_minor | int | default 0 |
| capital_gains_minor | int | plus-values mobilières, default 0 |
| pfu_opt_out | bool | option for the progressive barème instead of the 30 % PFU, default false |
| deductions_minor | int | charges déductibles (pension alimentaire, PER…), default 0 |
| credits_minor | int | réductions et crédits d'impôt, applied last, default 0 |
| created_at / updated_at | datetime | |

> **No estimate is stored.** The result is a pure function of this row plus the resolved parameters
> (§16), so it is computed on read like `/dashboard/summary` — and a stored estimate would go stale
> the moment an override or a declared figure changed. History comes from the profiles themselves:
> one row per year, kept.
>
> **Property income is not a column here.** It is derived from `properties` (§16), so the Impôts
> and Synthèse panels cannot disagree about the same rent.

### `tax_brackets`
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK → users null | **null = system, seeded** (same convention as `categories`) |
| tax_year | int | |
| kind | text | `ir` \| `ifi` |
| ordinal | int | 0-based, ascending |
| lower_bound_minor | int | inclusive floor of the band; the top band has no ceiling |
| rate_bps | int | |

### `tax_parameters`
| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK → users null | null = system, seeded |
| tax_year | int | |
| key | text | e.g. `pfu_income_tax_bps`, `micro_foncier_ceiling_minor` |
| int_value | int | |
| unit | text | `bps` \| `minor` \| `count` — what the integer means |

Unique on `(user_id, tax_year, key)` and on `(user_id, tax_year, kind, ordinal)` respectively.
**Resolution:** a user row shadows the system row for the same key; brackets are overridden as a
*whole set* per `(tax_year, kind)` — a half-replaced barème is not a barème. See §16.

### `mortgage_simulations`
Saved simulator scenarios — **inputs only**.

| column | type | notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK → users | |
| label | text | |
| property_price_minor | int | |
| down_payment_minor | int | apport |
| principal_minor | int | borrowed amount as declared (price + fees − apport by default) |
| annual_rate_bps | int | |
| insurance_monthly_minor | int | |
| term_months | int | |
| upfront_fees_minor | int | |
| created_at / updated_at | datetime | |

> Results are never stored, for the reason the schedule isn't: they are a function of these
> columns, and a saved result would outlive the inputs that justified it. `projections` is retired.

### `user_settings` (amended)
One column added: `declared_monthly_income_minor` (int null). The debt ratio needs a monthly
income; the ledger can compute one, but a user whose income arrives irregularly or partly outside
the tracked accounts needs to be able to say so. Null = derive from the ledger (§15); set = use
this figure. It lives in `user_settings` because it is a standing per-user fact, not a Phase 3
entity — and there is exactly one, so a table for it would hold one row and one useful column.

---

## 5. API contract (Phase 1)

REST/JSON, all under `/api/v1`. Auth via bearer token (opaque or JWT; see §8). All endpoints
are user-scoped — a user only ever sees their own rows.

> **Why REST, not GraphQL.** GraphQL's wins (client-chosen fields, collapsing many resources
> into one round trip) require many heterogeneous remote clients and network latency to pay off.
> This app has one client (the Flutter app we control) talking to a **loopback sidecar** where
> round-trip cost is ~0, so those wins are moot — while GraphQL would add N+1/dataloader
> complexity, weaker caching, and awkward multipart uploads (our OFX import). FastAPI + REST
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

POST   /imports             multipart: file + account_id → import_batch
GET    /imports             → [import_batch]            (history)
GET    /imports/{id}        → import_batch

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

## 5b. API contract (Phase 2)

Same conventions: `/api/v1`, bearer auth, user-scoped, same error envelope.

```
GET    /settings                    → user_settings          (created lazily if absent)
PATCH  /settings                    {ai_enabled?, inference_base_url?, model_tag?,
                                     confidence_threshold?} → user_settings
GET    /settings/inference/health   → {reachable, models: [tag], detail?}   (never 5xx — an
                                       unreachable runtime is a normal, reportable state)

POST   /categorization/runs         {account_id?, scope: pending|all} → 202 run
GET    /categorization/runs         ?limit → [run]                     (history, newest first)
GET    /categorization/runs/{id}    → run                              (polled for progress)
POST   /categorization/runs/{id}/cancel → run

GET    /rules/suggestion            ?transaction_id → {match_field, match_type, pattern}
                                     (the rule form's pre-fill; a default, not a constraint —
                                      the client may override every field)
POST   /rules/preview               {match_field, match_type, pattern, account_id?}
                                    → {match_count, samples: [transaction]}   (max 3 samples)
POST   /rules/from-transaction      {transaction_id, match_field, match_type, pattern,
                                     category_id, apply_now} → {rule, recategorized_count}

GET    /recurring                   ?status&account_id → [series]
GET    /recurring/{id}              → series + [occurrence with transaction]
POST   /recurring/detect            {account_id?} → {created_count, updated_count}
POST   /recurring                   {label, account_id, expected_amount_minor, cadence,
                                     category_id?} → series            (is_manual = true)
PATCH  /recurring/{id}              {label?|category_id?|cadence?|expected_amount_minor?|status?}
DELETE /recurring/{id}              (manual → hard delete; detected → status = dismissed)
GET    /recurring/summary           → {monthly_total_minor, active_count, cancelled_count,
                                       cadence_counts: {monthly, quarterly, yearly, …},
                                       next_charge: {series_id, label, amount_minor, due_on}?,
                                       price_increases: [{series_id, delta_minor, changed_at}],
                                       missed: [{series_id, expected_on, days_late}], currency}

GET    /goals                       ?status → [goal + {progress_minor, progress_pct}]
POST   /goals                       {name, target_minor, target_date?, icon, color}
PATCH  /goals/{id}                  (incl. {status} — archive and restore)
DELETE /goals/{id}                  (archive, not hard delete — allocations are history)
GET    /goals/{id}/allocations      → [allocation]
POST   /goals/{id}/allocations      {amount_minor, allocated_on, note?} → allocation
DELETE /goals/{id}/allocations/{allocation_id}

POST   /backup/export               → application/zip (.finstride) + header X-Backup-Summary:
                                       summary JSON; stamps user_settings.last_backup_at
POST   /backup/inspect              multipart file → summary {format_version, app_version,
                                       exported_at, currency, counts: {accounts, transactions,
                                       categories, rules, recurring, goals}}
POST   /backup/restore              multipart file → summary   (replaces all the caller's data)
                                     errors: BACKUP_INVALID | BACKUP_TOO_NEW |
                                       BACKUP_CURRENCY_MISMATCH (422) · BACKUP_RUN_ACTIVE |
                                       BACKUP_CONFLICT (409)

GET    /database/summary            → {counts: {accounts, transactions, categories, rules,
                                       recurring, goals}} — the caller's rows; `categories`
                                       counts their own, never the system catalog
POST   /database/reset              → the same counts, for what was deleted
                                     errors: RESET_RUN_ACTIVE (409)
```

> **Why `/rules/from-transaction` instead of a flag on `PATCH /transactions/{id}`.** The
> "always categorise X as Y" affordance does two things — correct one row *and* create a rule
> that may recategorise many others. Folding that into the transaction patch would give one
> endpoint two blast radii and a response shape that sometimes reports a bulk count. Separate,
> the patch stays a single-row edit and the learning step reports what it changed.

> **Why the suggestion is a server call and not client-side string work.** Deriving the pattern
> means knowing which parts of a French bank label are noise — the same knowledge the import
> pipeline already applies when it cleans a description and extracts a merchant. A second copy
> of those heuristics in Dart would drift from the first, and the drift would show up as rules
> that don't match the transaction they were suggested from.

---

## 5c. API contract (Phase 3)

Same conventions: `/api/v1`, bearer auth, user-scoped, same error envelope. Every rate in a
payload or a response is an integer in basis points (§4c); every amount is integer minor units.

```
GET    /mortgages               ?status → [mortgage + {monthly_payment_minor,
                                  total_instalment_minor, outstanding_principal_minor,
                                  paid_principal_pct, remaining_months, next_payment_on}]
POST   /mortgages               {label, lender, repayment_type, principal_minor,
                                 annual_rate_bps, insurance_monthly_minor, term_months,
                                 first_payment_date, upfront_fees_minor?, property_id?} → mortgage
GET    /mortgages/{id}          → mortgage + the derived figures above + {total_interest_minor,
                                  total_insurance_minor, total_cost_minor, taeg_bps, last_payment_on}
PATCH  /mortgages/{id}
DELETE /mortgages/{id}           (archive, not hard delete — consistent with accounts and goals)
GET    /mortgages/{id}/schedule ?from&to&granularity=month|year → {
          rows: [{ordinal, due_on, instalment_minor, interest_minor, principal_minor,
                   insurance_minor, outstanding_after_minor}],
          totals: {interest_minor, principal_minor, insurance_minor}, currency}
          (derived per request — §15; `year` granularity aggregates the same rows)
GET    /mortgages/summary       → {total_outstanding_minor, monthly_charge_minor,
                                   debt_ratio_bps|null, monthly_income_minor|null,
                                   income_source: ledger|declared|unknown,
                                   hcsf_limit_bps, over_limit, active_count, currency}

GET    /properties              ?archived → [property + {user_share_value_minor}]
POST   /properties              {label, kind, market_value_minor, valued_on, ownership_bps?,
                                 acquisition_price_minor?, acquired_on?, annual_rent_minor?,
                                 annual_charges_minor?, property_regime?} → property
GET    /properties/{id}         → property + {user_share_value_minor, linked_mortgages: [id]}
PATCH  /properties/{id}
DELETE /properties/{id}          (archive)

GET    /tax/profiles            → [profile]                     (one per declared year, desc)
GET    /tax/profiles/{year}     → profile                       (created lazily with defaults)
PATCH  /tax/profiles/{year}     {household?, dependents_count?, …} → profile
GET    /tax/profiles/{year}/estimate → {
          parts, taxable_income_minor, ir_minor, ir_before_decote_minor, decote_minor,
          quotient_capped: bool, average_rate_bps, marginal_rate_bps,
          pfu: {base_minor, income_tax_minor, social_charges_minor} | null,
          barème_capital_minor | null,           // when pfu_opt_out
          property: {regime, gross_minor, allowance_minor, net_minor, social_charges_minor},
          ifi: {base_minor, gross_minor, decote_minor, due_minor} | null,
          total_due_minor, breakdown: [{key, amount_minor}],
          tax_year, parameter_source: seeded|overridden, ignored_keys: [key], currency}
GET    /tax/prefill             ?year → {salaries_minor, pensions_minor, dividends_minor,
                                  interest_minor, source: ledger, months_covered,
                                  per_field_confidence: {field: low|medium|high}}
                                  (a suggestion the user accepts field by field — never written
                                   automatically, same reasoning as `/rules/suggestion`)
GET    /tax/parameters/{year}   → {brackets: {ir: [...], ifi: [...]}, parameters: {key: {int_value,
                                   unit}}, overridden: {keys: [key], bracket_kinds: [kind]}}
PATCH  /tax/parameters/{year}   {parameters?: {key: int_value},
                                 brackets?: {ir?: [...], ifi?: [...]}} → the resolved set
                                 (writes user-owned rows; a bracket kind is replaced wholesale)
DELETE /tax/parameters/{year}   ?key&kind → the resolved set   (drops overrides, back to seeded)

GET    /simulations             → [simulation]
POST   /simulations             {label, property_price_minor, down_payment_minor, principal_minor,
                                 annual_rate_bps, insurance_monthly_minor, term_months,
                                 upfront_fees_minor?} → simulation
PATCH  /simulations/{id}
DELETE /simulations/{id}         (hard delete — a scenario is a scratchpad, not history)
POST   /simulations/compute     {principal_minor, annual_rate_bps, insurance_monthly_minor,
                                 term_months, upfront_fees_minor?, property_price_minor?,
                                 down_payment_minor?, include_existing_loans?: bool} → {
          monthly_payment_minor, total_instalment_minor, total_interest_minor,
          total_insurance_minor, total_cost_minor, cost_over_price_bps|null, taeg_bps,
          yearly: [{year, interest_minor, principal_minor, outstanding_after_minor}],
          debt_ratio_bps|null, hcsf: {within_ratio, within_term, limit_bps, max_term_months},
          max_borrowable_minor|null, currency}
          (stateless — nothing is persisted; §17)

GET    /networth/summary        → {assets: {accounts_minor, properties_minor},
                                   liabilities: {mortgages_minor}, net_worth_minor,
                                   series: [{month, net_worth_minor}],     // last 12 months
                                   property_values_held_flat: bool, valued_on_oldest: date|null,
                                   currency}
```

> **Why `/tax/prefill` is a separate read and not a prefilled profile.** A tax figure the app
> guessed and wrote into the profile would be indistinguishable, later, from one the user
> declared — and an estimate is only as defensible as the user's own numbers. Kept separate, the
> ledger offers and the user decides, field by field.

> **Why the estimate reports `ignored_keys`.** An estimator that silently omits a regime invites
> the user to trust a total that was never trying to be complete. The endpoint names what it did
> not model (§16), so the UI can show it next to the figure rather than in a footnote nobody reads.

---

## 6. Import pipeline

One **canonical transaction model** is the target of every parser. The rest of the app never
knows the source format.

1. **Validate file** — reject if `file_hash` already imported for this account.
2. **Parse to canonical** —
   - **OFX/QFX:** parse `STMTTRN` records; use `FITID` as the dedup key; read currency and
     account id; derive `period_start/end` from transaction date range.
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

**Phase 2 (adds the model):**
- Unmatched transactions go to the SLM with a prompt containing the category list + cleaned
  description/merchant + amount sign + a small few-shot set.
- If returned `confidence ≥ threshold` (default 0.80, configurable): assign,
  `source = model`, `needs_review = false`. Else `needs_review = true`.
- User confirms/corrects in the review queue. A user correction may offer "always categorise
  X as Y" → creates a `categorization_rule` (the system learns cheaply and deterministically).

This is the small-model-with-deferral pattern: the cheap path handles the easy majority and
only genuinely uncertain items reach the human.

**Stage 2 runs asynchronously, never inside the import request.** An import finishes on rules
alone and returns immediately; it then enqueues a `categorization_run` over the rows it left
`needs_review`. The frontend polls the run for progress and the transaction list refreshes as
rows resolve. Rationale: a few hundred rows through a local SLM is minutes of work, and binding
that to the upload request would make imports appear to hang and let a stalled runtime become a
stalled import — the one thing §"graceful degradation" forbids.

Run mechanics:
- **One run at a time per user.** Requesting a run while one is `pending`/`running` returns the
  in-flight run rather than starting a second — two passes over the same rows would race on
  `category_id`.
- **Progress is committed incrementally** (per batch, not at the end), so a crash keeps the work
  already done and `processed_count` is always truthful.
- **Startup reconciliation:** any run still `running` when the sidecar boots is marked `failed`
  — its executor died with the process.
- **Cancellation** is cooperative: the executor checks the run's status between batches.
- A row already carrying `source = user` or `source = rule` is never re-examined by a run.
- **Malformed replies and per-row runtime errors never abort the run.** A row that can't be
  parsed into `{category_id, confidence}` counts as deferred; the run ends `partial` if any row
  failed, `success` if none did.

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
- Local inference runtime: **`llama.cpp` (`llama-server`) or Ollama**, whichever the user runs —
  reached over the OpenAI-compatible `/v1` surface both expose. Default model **Gemma 4 E4B**
  (configurable); optional finance-tuned 8B model for the Phase 3+ insights feature
- Docker (dev) · native installers (release)

---

## 11. Definition of done (per feature slice)

A slice is done when: it matches this spec; has passing unit tests with external deps mocked;
passes lints; ships UI strings in both `fr` and `en`; money is integer minor units; and the
work lands as one or more Conventional Commits.

---

> §12 and §13 are appended rather than inserted so the existing §1–§11 numbering — referenced by
> every skill and task card — stays stable.

## 12. Recurring / subscription detection (Phase 2)

Deterministic, no model involved. The detector is a pure function over a user's transactions
producing candidate series; persistence and lifecycle sit above it.

**Grouping.** Rows are grouped per account by `merchant_key`: `merchant` when extracted, else
`description_clean` stripped of the parts banks vary between occurrences — dates, card-sequence
digits, trailing reference numbers — then case-folded and whitespace-collapsed. Only outflows
(`amount_minor < 0`) are considered.

**Qualification.** A group becomes a series when it has **≥ 3 occurrences** whose gaps are
regular: the median gap classifies the cadence (weekly 5–9 d, monthly 26–35 d, quarterly
85–95 d, yearly 350–380 d) and **each** gap must sit within tolerance of that median (±25 %,
floor ±3 days). Amounts must agree too: every occurrence within **±10 % or ±200 minor units**
(whichever is larger) of the median — the floor keeps small subscriptions from failing on
rounding, the percentage keeps large ones from absorbing a real price change.

**Signals.**
- *Price change*: the most recent occurrence sits outside the amount tolerance of the median of
  the previous ones, but the cadence still holds. Record the delta and its date, and re-baseline
  `expected_amount_minor` on the newer amount.
- *Missed charge*: `next_expected_date` has passed by more than the cadence tolerance with no
  new occurrence. Derived at read time — never persisted, since it stops being true the moment
  the charge lands.

**Idempotence.** Re-running the detector matches existing series on `(account_id, merchant_key)`
and updates them in place. It **never** touches a series with `is_manual = true`, never
resurrects one the user set to `dismissed` or `cancelled`, and never overwrites a user-edited
`label` or `category_id`. As with §7's rule engine: user intent is sacred.

**`monthly_total_minor`** normalises every non-dismissed series to a monthly figure
(weekly ×52/12, quarterly ÷3, yearly ÷12) so the burden of a mixed set is one comparable number.

## 13. Savings goals / virtual envelopes (Phase 2)

A goal is a target the user allocates money toward on paper. It is **purely virtual**: creating,
funding, or completing a goal writes no transaction and changes no account balance.

- `progress_minor = sum(goal_allocations.amount_minor)`; allocations are signed, so taking money
  back out is a negative allocation and the history stays append-only rather than mutable.
- `progress_pct = progress_minor / target_minor`, clamped to `[0, 1]` for display; the raw value
  is reported unclamped so an over-funded goal can say so.
- A goal flips to `status = reached` when progress ≥ target. It does not auto-archive — reaching
  it is the rewarding moment the UI is built around (§9: encouraging UX). Archiving is an
  explicit user action, and reversible: an archived goal keeps its allocation history and can be
  restored (`PATCH /goals/{id} {status}`).
- **A goal is not linked to an account.** Earlier drafts carried a display-only `account_id`; the
  drawn design (`docs/design/11-goals.md`) shows no account anywhere — not on the card, the
  detail header, or the allocation modal — so the column has no remaining purpose and is not
  built. The only account-derived figure in the feature is the aggregate savings total behind the
  over-allocation banner, which is read from accounts, not stored on the goal.
- **Over-allocation is a warning, not an error.** Total allocations across active goals may
  exceed the user's actual savings balance; the UI says so plainly and the API still accepts it.
  Blocking it would require the app to be right about which money is "savings", which it isn't.

## 14. Backup and restore (Phase 2)

A user can export everything they own to one `.finstride` file and restore it later, on this
machine or another (`docs/design/09-settings.md` §Sauvegarde et restauration).

- **Container**: a ZIP holding `manifest.json` and one `<table>.jsonl` per table, one row per
  line — original UUIDs, integer minor units, ISO-8601 dates/timestamps. The manifest carries
  `format: "finstride-backup"`, an integer `format_version`, the backend `app_version` (display
  only), `exported_at`, `currency` and per-table row counts, so a file can be summarised without
  reading its rows.
- **Scope**: the caller's rows only — categories (user-owned), accounts, balance snapshots,
  import batches, transactions, rules, recurring series/occurrences, goals/allocations,
  categorisation runs, settings. Never `users` or `auth_tokens`: credentials do not travel in a
  file, and a restore lands in the signed-in account (`user_id` is rewritten to the caller).
- **Refusals before any write**: not an archive (`BACKUP_INVALID`), a `format_version` newer
  than the build reads (`BACKUP_TOO_NEW`), a currency other than the user's
  (`BACKUP_CURRENCY_MISMATCH`, Phase 1 is single-currency), a categorisation run in flight
  (`BACKUP_RUN_ACTIVE`).
- **Restore is one transaction**: delete the caller's rows, then insert table by table in FK
  order. Every foreign key must point at a row restored from the same archive (or a system
  category); any malformed row, dangling reference or float in an integer column rolls the whole
  restore back. Row ids are kept, so restoring into a *different* user while the original owner
  still exists in the same database collides (`BACKUP_CONFLICT`) and changes nothing.
- The archive is **not encrypted** — the UI says so. Runs that were in flight in the archive
  are restored as `failed`; `last_backup_at` is a fact about this install and survives a restore.
- **Resetting the database** (`docs/design/09-settings.md` §Zone de danger) deletes the same
  scope minus `user_settings`: the profile's contents go, its locale, AI configuration and
  `last_backup_at` stay. It is one transaction — a refusal deletes nothing — is refused while a
  categorisation run is in flight (`RESET_RUN_ACTIVE`), re-seeds the system catalog on its way
  out, and never touches another profile's rows or any `.finstride` file already exported. The
  confirmation reports the counts read *before* the delete, so the user is told what went.

---

> §15–§19 are appended for the same reason §12 and §13 were: every skill and task card cites the
> existing numbering, so Phase 3 extends the tail rather than renumbering the middle.

## 15. Mortgages & debt ratio (Phase 3)

Panel « Crédits » (`/mortgages`), first of the new « Patrimoine » nav group. A mortgage is
**declared, standalone and never linked to the ledger** — no account, no transactions, no recurring
series. The same call as goals (§13): the feature computes *about* the user's money without
claiming to be a record of it, which keeps the engine a pure function and keeps an imported
statement from ever contradicting a schedule.

**The schedule is a pure function of the loan row** (§4c) and is recomputed per request.

- Monthly rate `i = annual_rate_bps / (12 × 10 000)`, carried as an exact `Decimal`, never a float.
- `constant_payment`: `payment = P × i / (1 − (1 + i)^−n)`, rounded half-up to minor units once,
  then held constant. Per period: `interest_k = round_half_up(outstanding_{k−1} × i)`,
  `principal_k = payment − interest_k`.
- **The final instalment absorbs the rounding residue**: `principal_n = outstanding_{n−1}` and
  `payment_n = principal_n + interest_n`. Without that, a 300-row schedule ends a few cents off and
  the panel shows a loan that was never quite repaid.
- `interest_only`: every instalment is `round_half_up(P × i)`; the principal is repaid whole at
  term as one final `principal_n = P`.
- **Insurance rides on top of the échéance and is never amortised**:
  `total_instalment_minor = payment_minor + insurance_monthly_minor`. It is not interest, it does
  not reduce the principal, and folding it into either would misstate both the cost and the payoff.
- **Invariants, asserted in tests, not hoped for**: `Σ principal_k = principal_minor`;
  `outstanding_after_n = 0`; no `principal_k ≤ 0`. A rate high enough that the first instalment
  does not cover its own interest is rejected at validation (422) rather than producing a loan that
  grows — the closed form has no answer there and neither does the UI.
- `taeg_bps` is the internal rate of return of the **actual** cash flows — advance
  `principal − upfront_fees` against instalments including insurance — solved by bisection on the
  monthly rate and annualised as `(1 + m)^12 − 1`. Reported as *indicative*: a real TAEG includes
  fees we never see.

**Debt ratio (taux d'endettement).** `debt_ratio_bps = Σ active loans' total_instalment_minor /
monthly_income_minor`, in bps.

- Income is **derived with an override**: `user_settings.declared_monthly_income_minor` when set,
  otherwise the median of the last 12 complete months' `income`-kind category totals across
  non-archived accounts. The response says which (`income_source`), because a ratio whose
  denominator the user can't see is a number they can't check.
- With neither a declaration nor enough ledger history (< 3 complete months), the ratio is `null`
  and the panel says why. A ratio invented from one month of data is worse than no ratio.
- The HCSF reference points are parameters, not law-in-code: `hcsf_limit_bps` (3500) and
  `max_term_months` (300). Exceeding them is shown as information, never as a refusal — **the app
  does not make lending decisions and says so in the panel.**

**Deferred by explicit decision (do not build in Phase 3):** early/partial repayment, variable and
stepped rates (taux variable, prêt à palier), deferred amortisation (différé), multi-line loans,
PTZ, and insurance quoted as a rate on outstanding capital. Each one breaks the closed form and
needs persisted loan *events* replayed over the schedule — a larger feature than this one.

## 16. French tax estimation (Phase 3)

Panel « Impôts » (`/tax`). **Estimation-first, and loudly so**: this is an order-of-magnitude
figure to plan with, not a return, not advice, and never a filing. The panel carries that
statement beside the total, not in a footnote, and every response reports the regimes it skipped
(`ignored_keys`, §5c).

**Parameters are data, seeded per year and user-overridable** (§4c). Resolution: a user row shadows
the system row for its key; a bracket *kind* is overridden as a whole set. Every estimate reports
`parameter_source` and its `tax_year`, so a figure can be traced to the numbers that produced it.
The seed card must **verify each figure against the official source and record the date of that
check in the migration** — the values below are what was known at authoring, and a barème is the
one input in this app that changes annually without anyone touching the code.

Seeded set (tax year 2025 income, stored as minor units / bps):

| key | value |
|---|---|
| `ir` brackets | 0 % ≤ 11 497 € · 11 % → 29 315 € · 30 % → 83 823 € · 41 % → 180 294 € · 45 % above |
| `salary_allowance_bps` / floor / ceiling | 1000 · 504 € · 14 426 € |
| `quotient_half_part_cap_minor` | 1 791 € |
| `decote_threshold_single_minor` / `_couple_minor` / `decote_rate_bps` | 889 € · 1 470 € · 4525 |
| `pfu_income_tax_bps` / `social_charges_bps` | 1280 · 1720 |
| `dividend_allowance_bps` | 4000 (barème option only) |
| `micro_foncier_allowance_bps` / `micro_foncier_ceiling_minor` | 3000 · 15 000 € |
| `ifi` brackets | 0 % < 800 000 € · 0,5 % → 1 300 000 € · 0,7 % → 2 570 000 € · 1 % → 5 000 000 € · 1,25 % → 10 000 000 € · 1,5 % above |
| `ifi_threshold_minor` · `ifi_primary_residence_allowance_bps` | 1 300 000 € · 3000 |
| `ifi_decote_base_minor` / `ifi_decote_rate_bps` | 17 500 € · 125 (applies 1,3–1,4 M€) |

**Pipeline, in this order:**

1. **Salaries and pensions** → 10 % abattement per person, floored and capped by the parameters.
2. **Property income**, derived from `properties` — never declared twice (§4c). `micro_foncier`
   when gross rent ≤ ceiling: 30 % abattement. `reel`: gross − `annual_charges_minor`, floored at
   0. Social charges at 17,2 % apply to the net figure.
3. **Capital income** goes down one of two roads, chosen by `pfu_opt_out`: the **PFU** (12,8 % IR +
   17,2 % PS, flat, outside the barème), or the **barème**, where dividends take the 40 % abattement
   and capital gains and interest enter in full — still with 17,2 % PS.
4. **Revenu net imposable** = the barème-taxed categories − `deductions_minor`, floored at 0.
5. **Parts**: 1 (single) or 2 (couple), + 0,5 for each of the first two dependents, + 1 per
   dependent from the third, + 0,5 when `single_parent`.
6. **IR brut** = `barème(RNI / parts) × parts`, then the **plafonnement du quotient familial**: the
   advantage the half-parts above the base (1 or 2) confer is capped at `quotient_half_part_cap`
   per half-part, and the capped figure wins when it is higher. `quotient_capped` reports whether
   it bit.
7. **Décote**, then `− credits_minor`, floored at 0. The IR is **rounded to the whole currency
   unit** (French practice); every intermediate stays in minor units.
8. **IFI**, only when the base reaches the threshold: `Σ (market_value × ownership_bps)` over
   non-archived properties, primary residence less 30 %, **minus the outstanding principal of the
   mortgages linked to those properties** (`property_id`, outstanding from §15). Then the barème
   from 800 000 € and the 1,3–1,4 M€ décote.
9. **Total** = IR net + PFU IR + social charges + IFI, with a per-component `breakdown` so the
   total is never a number without a derivation.

**Knowingly not modelled** — the estimate names these rather than absorbing them: prélèvement à la
source reconciliation, PER/Madelin beyond a lump `deductions_minor`, déficits fonciers and their
carry-forward cap, CSG déductible on barème-taxed capital income, holding-duration abattements
(PEA, dirigeant, plus-values immobilières), IR and PS on property *sales*, micro-BIC/BNC and LMNP,
taxe foncière and taxe d'habitation, IFI liabilities other than linked mortgages, foreign income
and treaties, and parts for invalidity or veteran status. **A tax estimate that hides its own gaps
is worse than no estimate**, so this list is part of the feature, not a disclaimer bolted on.

**The parameters live inside the Impôts panel**, not in Paramètres. They are not a preference like
a locale or an engine address — they are *the working of the estimate*, and the only moment a user
wants to see or change one is while reading a total that looks wrong. Sending them to a settings
tab would put the explanation of a number in a different panel from the number, and the round trip
would cost the user the context they came with. So the panel carries its own « Paramètres fiscaux »
view (barème rows and the parameter set for the displayed year, editable in place, « Rétablir les
valeurs officielles » to drop the overrides), reachable from the estimate itself; an overridden
figure is marked « ajusté » wherever it appears, and that marker is the way in.

## 17. New-mortgage projection simulator (Phase 3)

Panel « Simulateur » (`/simulations`). `POST /simulations/compute` is **stateless** and shares the
schedule engine of §15 — one implementation, so a simulated loan and a declared one can never
disagree about the same inputs. Saved scenarios store inputs only (§4c).

- Outputs: monthly instalment (payment + insurance), total interest, total insurance, total cost,
  cost-over-price ratio, indicative `taeg_bps`, and a **year-by-year** summary rather than 300 rows
  — the month-level detail is what `/mortgages/{id}/schedule` is for once the loan is real.
- `include_existing_loans` adds the user's active mortgages to the ratio, which is the question the
  user is actually asking: not "can I afford this loan" but "can I afford this loan *too*".
- `max_borrowable_minor` solves §15's formula backwards for the principal that lands the ratio
  exactly on `hcsf_limit_bps` at the given rate and term — null when income is unknown.
- Up to **3 scenarios compared side by side**; beyond that the comparison stops being readable and
  starts being a spreadsheet.
- The same refusal as §15: an HCSF breach is displayed, never enforced, and the panel repeats that
  no lender is bound by any of this.

## 18. Net-worth synthesis (Phase 3)

Panel « Synthèse » (`/networth`). One derived view, no new stored money.

- **Assets** = derived balances of non-archived accounts (§4) + `Σ (market_value × ownership_bps)`
  over non-archived properties. **Liabilities** = `Σ` outstanding principal of active mortgages
  (§15). Net worth is the difference.
- **Goals are excluded.** An envelope is a label on money already counted inside an account (§13);
  adding allocations to assets would count the same euros twice. The panel says so where a user
  would expect to see them.
- **Subscriptions and estimated tax are not liabilities.** A future charge is not a debt, and
  treating next month's Netflix as one would make net worth a mood rather than a measurement.
- **The 12-month series is honest about what it can't know.** Account history comes from the
  monthly balance snapshots (§4) and mortgage history from the derived schedules, but a property
  has exactly one declared value — so past points hold property values flat, the response flags it
  (`property_values_held_flat`, `valued_on_oldest`), and the chart carries that caveat inline. A
  back-dated property valuation the user never gave is a fabrication, not an interpolation.

## 19. Phase 3 open decisions (not decided — do not guess)

Three questions sit inside Phase 3's boundary that this spec deliberately does **not** answer. A
task card must not claim any of them until the user has ruled:

1. **Packaging of the inference runtime** — §3 defers the bundle-or-not call to Phase 3, to be made
   against *measured* installer sizes. Nothing in §15–§18 depends on it, so it is sequenced
   separately from the Patrimoine work.
2. **The finance-tuned 8B "insights" feature** — §10 calls it Phase 3+; §2's Phase 3 row does not
   include it. Unscheduled until scoped.
3. **Whether a tax estimate can be exported** (a PDF or printable summary). Plausible, unspecified,
   and out of scope here — an exportable estimate raises the bar on the disclaimer in §16.
