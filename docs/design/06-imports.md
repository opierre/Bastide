# Panel: Imports (+ CSV mapping wizard)

Where users bring in bank data (OFX/QFX/CSV) and review past imports. Two sub-views: the import
action and the import history. Show the full app shell.

## Top bar (this panel)
Title "Imports" + profile. (Account selection happens within the panel.)

## Content layout
**A. Import action**
- Account selector + a drop zone / file picker ("Drop an OFX, QFX, or CSV file").
- OFX/QFX import directly. CSV launches the **mapping wizard** (or offers to reuse a saved
  template if one exists for that bank).
- After import: a result summary card — new vs duplicate counts, coverage period, success/
  partial/failed status (failed shows a calm error message).

**B. CSV mapping wizard** (show as a focused step/modal)
- Controls: delimiter (default `;`), encoding (Latin-1/UTF-8), date format (e.g. `dd/MM/yyyy`),
  decimal separator (`,`), amount strategy (signed vs separate débit/crédit columns), header
  rows to skip.
- Column mapping: map file columns → canonical fields (date, amount/debit/credit, description).
- **Live preview table** of a few parsed rows so the user validates before saving the template +
  importing. Save-template toggle ("Remember this layout for <bank>").

**C. Import history**
- Table/list of past batches: file name, format badge (OFX/QFX/CSV), import date, **coverage
  window** (period start–end), counts (new / duplicates), status. Localized dates.

## States to show
1. Import action with a file selected. 2. CSV wizard with the live preview populated.
3. Import history with several past imports (incl. one with duplicates and one failed).
4. Empty history state.

## Notes
The wizard is the most complex screen — keep it legible and stepwise. French + English variants.
Dates/amounts locale-formatted.
