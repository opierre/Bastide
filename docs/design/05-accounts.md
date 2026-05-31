# Panel: Accounts

Manage the user's accounts. Multi-account, all in the user's single currency (Phase 1). Show the
full app shell with this in the content region.

## Top bar (this panel)
Title "Accounts" + a primary "Add account" button (accent) + search + profile.

## Content layout
- **Account cards** (grid or list): each shows institution **logo or monogram**, account name,
  type (checking/savings/credit/cash), and the current **balance** in tabular figures, locale-
  formatted, with sign color. A small overflow menu per card: Edit, Archive.
- Optional summary header: total balance across accounts (single currency).
- **Add/Edit form** (panel or modal): Name, Type (select), Institution (with logo preview when
  recognized), Opening balance. Currency is shown **read-only** (the user's currency) — no picker
  in Phase 1.

## States to show
1. Populated with 3–4 varied accounts (a bank checking, a savings, a credit card) — show real
   logos where plausible and a monogram fallback for an unknown institution.
2. The Add/Edit form open.
3. Empty state: "Add your first account" with a clear CTA.

## Notes
Balances right-aligned, tabular. Monogram fallback must look intentional (colored chip with
initials), never a broken image. French + English variants for labels.
