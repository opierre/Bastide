# Panel: Dashboard

The hero screen and first impression after login. It must feel encouraging and make the month's
money legible at a glance. Show the **full app shell** with this in the content region.

## Top bar (this panel)
Title "Dashboard" + a **month selector** (e.g. "May 2026" with prev/next) + global search +
profile menu.

## Content layout
- **Headline stat cards** (row of 4), each value in Open Sans tabular figures with a small MoM
  **trend delta** (arrow + % in semantic color):
  1. Income (month) — up = green/good
  2. Expenses (month) — **up = red/bad** (don't show rising expenses as "positive")
  3. Net (income − expenses)
  4. **Savings rate** — make this the visually emphasized, first-class metric (e.g. larger card
     or a ring/gauge), since it's the behavior the app encourages.
- **By-category breakdown**: a donut or horizontal bar chart of expenses by category, using the
  app's category colors, with a legend listing category name + amount (locale-formatted) + %.
- Optional secondary row: a simple income-vs-expense visual for the month, or recent activity
  snippet — keep it calm, not cluttered.

## States to show (important)
1. **Populated**: realistic French data (amounts like `1 234,56 €`, French category names:
   Logement, Alimentation, Transport…). Also provide the English variant.
2. **Empty / no data yet**: an encouraging empty state — friendly illustration/space, a line
   like "Import a statement to see your money come to life," and a primary CTA to **Imports**.
3. Loading skeleton variant (cards + chart placeholders).

## Notes
Lead with progress and positive framing. Trend semantics must be correct (rising expense is not
green). Tabular figures; consistent category colors with the Transactions/Categories panels.
