---
name: multi-currency
description: Use whenever currency, FX, or per-account currency comes up in Bastide. Defines the current rule (one currency per user, chosen at registration, applied to all accounts), why the per-account currency column must stay anyway, and the outline of a future multi-currency design — so agents neither build FX prematurely nor strip the forward-compatible structure.
---

# Multi-currency

The app is deliberately single-currency. This skill exists mainly to stop two opposite mistakes:
building FX too early, or removing the structure that keeps FX cheap to add later.

## The rule

- The user picks **one currency at registration** (`users.currency`, ISO-4217), alongside locale.
- **All accounts use that currency.** Account creation defaults `accounts.currency` to
  `users.currency`. The UI offers no per-account currency picker.
- **No FX, no conversion, no rate fetching.** Dashboards, balances, savings rate, and totals all
  sum within the single currency. There is no "base vs account currency" distinction.

## Do NOT do (premature work)

- Don't add FX rate tables, ECB fetching, or conversion math.
- Don't add per-account currency selection UI.
- Don't write aggregation code that converts between currencies "just in case."

## Do KEEP (forward-compat, near-zero cost)

- **Keep the `currency` column** on `accounts` and `transactions`, populated with the user's
  currency. It is intentionally redundant today. **Never drop it** to "simplify" — removing
  it is the expensive mistake, because re-adding it later means a data migration over the whole
  ledger.
- Keep all money as **integer minor units + currency code** (per **database** skill). Mixed-unit
  currencies (e.g. JPY has 0 minor digits) are handled correctly because the code travels with
  the amount.

## Future design (outline only — not scheduled)

If per-account multi-currency is ever built:
- A user gets a **base/reporting currency**; each account keeps its own `currency`.
- Transactions stay stored in their **account currency**; conversion to base happens only for
  cross-account aggregates (net worth, total savings rate).
- **FX rates from ECB daily reference rates**, stored historically; cross-currency aggregates use
  the **transaction-date rate** (period-correct history), not today's rate. Cache rates for
  offline use.
- Display shows native amount + base-currency equivalent.

Because the `currency` columns and integer-minor-units already exist, this is **additive**
(new rate table + conversion service + base-currency setting) with no rewrite of existing rows.

## Agent guidance

If a task seems to need conversion logic, it's almost certainly mis-scoped — stop and confirm
with the user rather than introducing FX. If a task tempts you to drop a `currency` column to
reduce duplication, don't; reference this skill in the pushback.
