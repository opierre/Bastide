# Panel: Transactions

The workhorse list. Filterable, searchable transactions with inline category editing, plus a
review queue for uncategorized/uncertain items. Show the full app shell.

## Top bar (this panel)
Title "Transactions" + **global search** (over description/merchant) + profile. Filters live in
the panel header.

## Content layout
- **Filter bar**: account, date range, category, and a "Needs review" toggle.
- **Transaction list**: each **row** shows merchant **logo/monogram**, description, a **category
  chip** (with category color), date, and the **signed amount** (green income / red expense,
  tabular, right-aligned). Rows are calm and scannable; zebra or subtle separators only.
- **Inline category edit**: clicking the category chip opens a category picker; selecting one
  updates the row and clears its review flag.
- Pagination or infinite scroll.

## Review queue (sub-view or filtered mode)
- Surfaces only `needs_review` transactions (uncategorized in Phase 1).
- For each: quick category assignment; an optional **"Always categorize like this"** affordance
  (creates a rule — wired for the future AI learning loop).
- Encouraging framing: "X transactions to review" with progress as the user clears them.

## States to show
1. Populated list with French data (real merchant names, French categories, `1 234,56 €`).
   Also the English variant.
2. Category picker open on a row.
3. Review queue with several uncategorized items + the "always categorize" option.
4. Empty state (no transactions yet → CTA to Imports).

## Notes
Sign color + icon together (not color alone). Category chip colors consistent with Dashboard and
Categories. Tabular amounts. French + English variants.
