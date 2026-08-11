# P2-06b — Rule pack import & export
Scope: backend
Depends on: P2-06
Skills: fastapi-backend, database, i18n-l10n, testing
PROJECT.md: §5b, §7

## Objective
Make a set of categorization rules a portable file a user can import, export, and share. A pack
carries no ids, no priorities, and no user data — only `(field, type, pattern, category_key)`
tuples — so the same file works on any install. A bundled French starter pack ships in-repo and
is offered after the first import, which is what fixes day-one categorization for a user with no
rules and no inference runtime.

This card adds **no tables and no columns**. An imported rule is an ordinary
`categorization_rules` row matched by the P1-12 engine with `source='rule'`, so every existing
surface — the review queue, the rules editor, `POST /rules/apply` — renders and handles it
unchanged. That reuse is the whole point of the design; do not add a parallel code path.

## Files
- `backend/app/features/rules/packs/{__init__,schema,resolve,service}.py`
- `backend/app/features/rules/packs/builtin/fr-common.v1.json` — the bundled starter pack
- `backend/app/features/rules/router.py` — edit: mount the pack endpoints
- `docs/schemas/rule-pack.v1.schema.json` — machine-readable contract (already written)
- `backend/tests/features/rules/packs/{test_schema,test_resolve,test_import,test_export}.py`

## Contract slice
```
GET  /api/v1/rules/packs/builtin  → [{id, name, locale, rule_count}]
POST /api/v1/rules/packs/preview  {pack} | {builtin_id}
     → {name, total, new_count, duplicate_count, unresolved: [key],
        would_match_count, samples: [transaction]}
POST /api/v1/rules/packs/import   {pack} | {builtin_id}, apply_now
     → {created_count, skipped_count, unresolved: [key], recategorized_count}
GET  /api/v1/rules/packs/export   ?enabled_only → pack
```

## Pack format
Normative shape in `docs/schemas/rule-pack.v1.schema.json`. Summarised:

```json
{
  "format_version": 1,
  "name": "France — commerces courants",
  "locale": "fr",
  "rules": [
    {"field": "merchant", "type": "contains", "pattern": "CARREFOUR",
     "category_key": "category.food.groceries"}
  ]
}
```

Deliberately absent: `id`, `user_id`, `priority`, `created_at`. A pack is portable data, not a
row dump — carrying a priority would let a shared file preempt rules its recipient ordered
deliberately, and carrying ids would make the file install-specific.

## Steps
1. `schema.py` — Pydantic v2 models for the pack and its entries. `format_version` must be `1`;
   anything else is a 422 naming the supported version, never a best-effort parse. Reuse the
   existing `MatchField` literal; entries use a **narrowed** match-type literal (step 3).
   `pattern` is `max_length=255`, matching the column. Cap a pack at 1000 entries.
2. `resolve.py` — `category_key` → the caller's `categories` row whose `name` equals the key.
   System categories store the i18n key in `name` (`PROJECT.md` §4), which is exactly what makes
   a pack portable across locales: the key resolves the same for a French and an English user.
   - **v1 resolves system categories only.** A key with no match is reported in `unresolved` and
     its rule skipped. **Never auto-create a category** — a stranger's file must not be able to
     reshape someone's category tree, and a silently invented category is worse than a reported
     gap the user can fix.
   - Rules targeting user-defined categories are therefore not expressible in v1. That is a
     deliberate limit, not an oversight; note it in the export report (step 8).
3. **Reject `match_type: "regex"` in imported packs — 422.** `engine.py:34` runs
   `re.search(rule.pattern, value)` on every transaction with no timeout, and Python's `re` has
   no way to bound backtracking, so a hostile or merely careless pattern in a shared file is a
   denial-of-service against the importer's own machine. A hand-typed regex is a different risk
   class from one arriving in a file; the rules API keeps `regex`, packs do not. `contains`,
   `equals`, and `range` cover merchant matching. Revisit only behind a real regex guard.
4. Deduplicate on the natural key `(match_field, match_type, casefolded pattern, category_id)` —
   `contains`/`equals` match case-insensitively (`engine.py:30-32`), so a case-sensitive dedup
   key would admit duplicates the engine cannot tell apart. Deduplicate both **against the
   user's existing rules** and **within the pack itself**; count them in `skipped_count`.
   Re-importing the same pack twice must create nothing the second time.
5. Priority: append after everything the user has (`max(priority) + 1`, as in P2-06 step 3),
   preserving the pack's internal order. An imported rule never preempts a user-ordered one.
6. Import is atomic: all resolvable, non-duplicate rules land in one DB transaction, or none do.
   `apply_now=true` then runs the existing P1 apply path and returns its count, honouring its
   invariant that `source='user'` rows are never overridden. `apply_now=false` → 0.
7. `preview` writes nothing and reports what an import *would* do, including `would_match_count`:
   evaluate the P1 engine over the caller's currently-uncategorized transactions with
   `existing enabled rules + the pack's new rules`, and count the rows that come back with a
   category. Use the **engine itself**, not a `LIKE` query — same reasoning as P2-06 step 7, and
   first-match-wins means a naive per-rule count would double-count. Return up to 3 sample rows.
8. `export` emits the caller's rules in pack format, resolving `category_id` → key.
   - Rules pointing at a user-defined category or using `regex` cannot round-trip; omit them and
     report them, rather than emitting a pack that fails its own import.
   - The endpoint returns the pack **as a body for the UI to display before the user saves it**.
     Patterns can carry personal data — a landlord's name, `VIR SALAIRE DUPONT` — so export is a
     reviewed action, never a silent download. The frontend card owns that review step.
9. `builtin/fr-common.v1.json` — the bundled starter pack, loaded from disk and listed by
   `GET /packs/builtin`, so `preview`/`import` can take a `builtin_id` and the frontend can
   offer it without a file picker. Author it against the seed catalog's keys
   (`app/core/seed.py`); every key in it must resolve on a freshly seeded user, and a test
   asserts exactly that.

## Settled — operation types in the starter pack
`category.other.cash` has been added to the seed catalog (`app/core/seed.py`) for this card, so
`description_clean contains "RETRAIT"` has somewhere to land.

**No transfer category, deliberately.** A `VIR EMIS` is as likely to be a friend paying back
theatre tickets — which belongs under Loisirs — as a movement between the user's own accounts.
The operation type is knowable from the label; the *meaning* is not, and only the user knows it.
So the starter pack carries no `VIR EMIS` rule at all: those rows stay uncategorized and reach
the review queue, which is the correct place for a question the data cannot answer.

Do not add a transfer category as a convenience later without revisiting this.

## Acceptance
- A pack imports on a fresh user, creating one rule per resolvable entry, appended in pack order
  after any existing rules.
- Importing the same pack twice creates nothing the second time; `skipped_count` reports it.
- A pack containing `regex` is rejected 422; a pack with `format_version != 1` is rejected 422.
- An unresolvable `category_key` is reported in `unresolved`, its rule skipped, no category
  created, and the rest of the pack still imports.
- Import is atomic: an induced failure mid-import leaves zero rules created.
- `preview` writes nothing, and its `new_count`/`duplicate_count`/`unresolved` equal what a
  subsequent real import does.
- Export round-trips: exporting a user's rules and importing them into a second fresh user
  produces the same effective categorization, with user-category and regex rules reported as
  omitted.
- The bundled pack's every `category_key` resolves against a freshly seeded user.
- All endpoints user-scoped. `ruff` + `ty` clean.

## Tests
- `test_schema.py`: valid pack parses; `format_version` 0/2/missing → 422; `regex` entry → 422;
  pattern over 255 chars → 422; over 1000 entries → 422.
- `test_resolve.py`: system key resolves; unknown key reported and no category created;
  resolution is user-scoped (user A's pack cannot bind user B's category).
- `test_import.py`: append-after-existing priority order; intra-pack and against-existing dedup;
  double import is a no-op; atomicity under an induced failure; `apply_now` count correct and
  `source='user'` rows untouched; every bundled-pack key resolves on a seeded user.
- `test_export.py`: round-trip through import on a second user; user-category and regex rules
  omitted and reported; `enabled_only` honoured; nothing leaks another user's rules.

## Commits
- `feat(rules): add rule pack schema and category-key resolution`
- `feat(rules): add rule pack preview and import endpoints`
- `feat(rules): add rule pack export`
- `feat(rules): add bundled French starter rule pack`
