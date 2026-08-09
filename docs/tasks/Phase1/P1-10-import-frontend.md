# P1-10 — Import frontend
Scope: frontend
Depends on: P1-07, P1-08, P1-09
Skills: flutter-frontend, design-system, i18n-l10n, testing
PROJECT.md: §5, §6, §9

## Objective
Imports panel: pick an account + file, import OFX/QFX directly, guide CSV through a one-time
column-mapping wizard with live preview, and show import history (date, format, coverage, counts).

## Files
- `frontend/lib/features/imports/presentation/{imports_screen,csv_mapping_wizard,import_history.dart}`
- `frontend/lib/features/imports/application/imports_controller.dart`
- `frontend/lib/features/imports/data/imports_repository.dart`
- `frontend/lib/features/imports/domain/{import_batch,csv_template.dart}`
- ARB keys (fr+en); `frontend/test/features/imports/...`

## Steps
1. Repository + controller: list batches, upload import, csv-template CRUD, preview.
2. Import screen: select account, drop/pick file. If OFX/QFX → import directly. If CSV → launch
   the mapping wizard (unless a saved template for that bank exists → offer to reuse).
3. CSV wizard: choose delimiter/encoding/date format/decimal/amount strategy + map columns; show
   a **live preview** (parsed sample from the backend) before saving the template + importing.
4. Import result: show new vs duplicate counts and coverage window; clear success/partial/failed
   states (failed shows the error message, calmly).
5. Import history: list batches (file name, format, import date, period covered, counts, status).
6. ARB parity; analyze clean.

## Acceptance
- OFX import is one step; CSV first-time uses the wizard, thereafter reuses the saved template.
- Preview reflects parsing before commit; bad mapping is caught pre-import.
- History shows accurate dates, coverage, and counts; re-import shows duplicates handled.
- Consistent chrome; fr + en.

## Tests
- Controller test (mocked repo): import success/duplicate/failed transitions; template save+reuse.
- Widget test: wizard renders + preview; history renders localized dates/counts; fr + en.

## Commits
- `feat(imports): add imports repository and controller`
- `feat(imports): add file import and CSV mapping wizard with preview`
- `feat(imports): add import history view`
