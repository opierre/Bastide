# P1-03 — Database models, migrations & category seed
Scope: backend
Depends on: P1-01
Skills: database, architecture, i18n-l10n, testing
PROJECT.md: §4

## Objective
All Phase 1 SQLAlchemy models, Alembic configured with the initial migration, and an idempotent
seed of the rich (~25+) localized system categories. No endpoints yet.

## Files
- `backend/app/features/*/models.py` — models for: `users`, `accounts`, `transactions`,
  `categories`, `categorization_rules`, `import_batches`, `csv_templates`, plus an
  `account_balance_snapshots` table (monthly snapshot per account, per database skill).
  Place each model in its owning feature folder (`auth/`, `accounts/`, `transactions/`,
  `categories/`, `rules/`, `imports/`).
- `backend/migrations/` — Alembic env + the initial migration creating all tables, FKs, unique
  constraints (incl. `(account_id, fitid)` and `(account_id, dedup_hash)` indexes;
  `import_batches.file_hash`), and indexes for user-scoping.
- `backend/app/core/seed.py` (or a seed migration) — idempotent seed of system categories with
  i18n keys + fr/en names, organized as parent groups + subcategories.
- `backend/tests/test_models.py`, `backend/tests/test_seed.py`.

## Schema slice
Use `PROJECT.md` §4 exactly: UUID string PKs, UTC timestamps, money as signed integer `*_minor`
+ `currency`, `accounts.cached_balance_minor`, the `transactions` dedup fields, the
`categorization_rules`, `import_batches`, `csv_templates` tables. Add `account_balance_snapshots`
(id, account_id FK, period_end date, balance_minor int).

## Category seed (rich set, ~25+; localized fr/en)
Parent groups with subcategories, e.g.:
- **Logement/Housing**: Loyer/Rent, Prêt immobilier/Mortgage, Charges/Utilities, Assurance habitation/Home insurance
- **Alimentation/Food**: Courses/Groceries, Restaurants, Café/Coffee
- **Transport**: Carburant/Fuel, Transports en commun/Public transit, Stationnement/Parking, Entretien auto/Car maintenance
- **Santé/Health**: Médecin/Doctor, Pharmacie/Pharmacy, Mutuelle/Health insurance
- **Loisirs/Leisure**: Abonnements/Subscriptions, Sorties/Outings, Voyages/Travel
- **Achats/Shopping**: Vêtements/Clothing, Électronique/Electronics, Maison/Home
- **Finances**: Frais bancaires/Bank fees, Impôts/Taxes, Épargne/Savings (transfer), Intérêts/Interest
- **Revenus/Income**: Salaire/Salary, Remboursements/Refunds, Autres revenus/Other income
- **Divers/Other**: Non catégorisé/Uncategorized
Each: `kind` (income|expense|transfer), icon id, color, `is_system=true`, `user_id=null`.

## Steps
1. Define models in their feature folders; import them into Alembic's metadata.
2. Configure Alembic (env reads the same engine/config). Autogenerate, then hand-verify the
   initial migration (constraints + indexes present, types portable per database skill).
3. Implement idempotent seed (insert-if-absent by stable key) for the categories above.
4. Tests: migration applies on empty temp SQLite; seed is idempotent (running twice = same rows);
   constraints enforce dedup uniqueness.

## Acceptance
- `alembic upgrade head` builds the full schema on an empty DB.
- All money columns are integer; all PKs UUID strings; all timestamps UTC.
- Dedup unique indexes exist; `file_hash` uniqueness per account exists.
- Seed produces ~25+ localized system categories and is idempotent.

## Tests
- `test_models.py`: schema builds; unique/dedup constraints reject duplicates.
- `test_seed.py`: seed idempotency; categories have both fr + en names and valid `kind`.

## Commits
- `feat(db): add Phase 1 SQLAlchemy models`
- `feat(db): add initial Alembic migration with constraints and indexes`
- `feat(categories): seed localized system categories`
