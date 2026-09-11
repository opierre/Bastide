# P2-07 — Categories & rules frontend
Scope: frontend
Depends on: P2-06
Skills: flutter-frontend, design-system, i18n-l10n, testing
PROJECT.md: §5, §5b, §7, §9
Design: `docs/design/08-categories-rules.md` — normative

## Objective
Build the stubbed Catégories panel into the two-view management screen drawn in
`docs/design/08-categories-rules.md`: a category tree with spend share, and a priority-ordered,
drag-reorderable rules list with an editor that previews its match count. The backend already
exists (P1-11) — this card is UI + state only.

## Files
- `frontend/lib/features/categories/presentation/{categories_screen,category_row,category_form_modal}.dart`
- `frontend/lib/features/categories/application/categories_controller.dart`
- `frontend/lib/features/categories/data/categories_repository.dart`
- `frontend/lib/features/categories/domain/category.dart` — or reuse
  `features/transactions/domain/category.dart` if it already covers the fields; do not define a
  second shape for the same resource.
- `frontend/lib/features/rules/{presentation,application,data,domain}/...`
- `frontend/l10n/app_fr.arb`, `app_en.arb`; `frontend/test/features/{categories,rules}/...`

## Contract slice
```
GET/POST/PATCH/DELETE /api/v1/categories
GET/POST/PATCH/DELETE /api/v1/rules
POST /api/v1/rules/apply   {account_id?} → {recategorized_count}
POST /api/v1/rules/preview {match_field, match_type, pattern} → {match_count, samples}
GET  /api/v1/rules/packs/builtin → [{id, name, locale, rule_count}]
POST /api/v1/rules/packs/preview {pack} | {builtin_id} → {name, total, new_count,
                                   duplicate_count, unresolved, would_match_count, samples}
POST /api/v1/rules/packs/import  {pack} | {builtin_id}, apply_now → {created_count, …}
GET  /api/v1/rules/packs/export  ?enabled_only → pack
```

## Steps
1. Repositories + controllers for categories and rules. No logic in widgets (see the
   flutter-frontend skill): ordering, enable/disable, and the match preview all live in the
   controller.
2. Categories view per frame 08: parent rows with swatch, name, Système/Personnalisée badge,
   spend-share bar in the category's own hue, %, month amount, and lock vs ⋯ trailing;
   subcategory rows indented. System categories are read-only — the lock glyph, the absent ⋯,
   **and** a rejected patch are all three needed; do not rely on hiding the affordance alone.
3. Rules view: drag-reorderable rows writing `priority` back on drop, condition badge, monospace
   pattern, target CategoryChip, enable Toggle, and the « Exécuter les règles » action with the
   two-line toast (count + the reassurance that manual categories were untouched).
4. Rule editor modal: field/condition/priority row, pattern, target category, active toggle.
   The match preview calls `POST /rules/preview` (P2-06) and renders the count plus one example
   in the InlineBanner frame 08 draws — « Correspond à 7 transactions existantes — dont "CB
   CARREFOUR PARIS 15" du 14/05/2026. » Debounce it; a preview that fires per keystroke will
   hammer the sidecar. A 422 from an uncompilable regex renders on the pattern field, not as a
   preview count of zero — "no matches" and "not a valid pattern" are different answers.
5. Reordering and toggling are **optimistic with rollback**: apply locally, patch, and restore
   the previous order on failure with an error toast. A drag that visibly snaps back after a
   round trip reads as a broken list.
6. **Rule packs (P2-06b)** — an « Importer / Exporter » affordance on the rules view:
   - Import takes a file *or* a bundled pack from `GET /rules/packs/builtin`. Always call
     `POST /rules/packs/preview` first and show its report as a confirmation sheet — new count,
     duplicates skipped, unresolved categories, and the headline « Ce pack catégoriserait 342 de
     vos 500 transactions. » Never import straight from the file picker; the count is the whole
     reason the user can judge a stranger's pack.
   - A 422 (bad `format_version`, or a pack containing `regex`) renders as a plain explanation of
     why the file was refused, not a generic failure.
   - Export shows the pack contents **before** the user saves it, with the omitted-rules report
     and a note that patterns can contain personal detail. A silent download of a file carrying
     « VIR SALAIRE DUPONT » is the failure mode this review step exists to prevent.
   - The rules **empty state** offers the bundled French pack directly — that is where a new user
     with no rules actually is, and it is the cold-start path.
7. Empty states for both views; ARB keys for every string in fr **and** en; `flutter analyze`
   clean.

## Acceptance
- Both views match frame 08 (geometry, badges, hues, toggle treatment).
- System categories cannot be edited or deleted from the UI, and the API rejects it if forced.
- Reordering persists new priorities; the list order survives a reload.
- The rule editor previews the match count for the typed pattern (including `regex` and `range`,
  which no text search could approximate) and creates a working rule.
- « Exécuter les règles » shows the recategorized count.
- A pack import always shows the preview report before committing, and a refused pack explains
  why; export shows its contents before saving; the rules empty state offers the bundled pack.
- fr + en parity; no hard-coded user-facing strings.

## Tests
- Controller tests (mocked repos): load, create/patch/delete, reorder writes expected priorities,
  reorder failure rolls back, apply returns the count.
- Widget tests: system row renders lock and no ⋯; custom row renders ⋯; rules row renders the
  condition badge and target chip; disabled rule renders at reduced opacity; empty states render;
  fr and en both render in the same geometry.

## Commits
- `feat(categories): add categories repository and controller`
- `feat(categories): add category management view with spend share`
- `feat(rules): add reorderable rules view with editor and match preview`
- `feat(rules): add rule pack import and export with preview confirmation`
