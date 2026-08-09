# P2-12 — Subscriptions frontend
Scope: frontend
Depends on: P2-11
Skills: flutter-frontend, design-system, i18n-l10n, testing
PROJECT.md: §5b, §9, §12
Design: `docs/design/10-subscriptions.md` (frames ①–⑤) and `00-shared-design-block.md`
§Phase 2 additions (StatusPill, nav) — normative

## Objective
The Abonnements panel per `docs/design/10-subscriptions.md`: monthly burden summary, the series
list with cadence and next charge, price-increase and missed-charge signals, the lifecycle
actions, series detail with occurrence history, and manual creation.

## Files
- `frontend/lib/features/recurring/presentation/{subscriptions_screen,series_row,series_detail,series_form_modal}.dart`
- `frontend/lib/features/recurring/application/subscriptions_controller.dart`
- `frontend/lib/features/recurring/data/recurring_repository.dart`
- `frontend/lib/features/recurring/domain/{recurring_series,recurring_summary}.dart`
- `frontend/lib/core/navigation/sidebar_controller.dart` + `core/router/app_router.dart` — edit
- ARB keys (fr+en); `frontend/test/features/recurring/...`

## Steps
1. Add the « Abonnements » sidebar item (Gestion group, third; circular-arrow cycle icon) and its
   route, per the Phase 2 nav amendment in frame 00. Keep the existing pill/active-rail
   treatment — the fixed-chrome invariant is non-negotiable (§9).
2. Repository + controller: list with a status filter, summary, detail, detect, patch status,
   create manual, delete.
3. Summary row, three cards per frame ①: the iris-tinted **Charge mensuelle** hero (the only
   tinted card on the panel), **Abonnements actifs** with its cadence breakdown caption, and
   **Prochain prélèvement**. All three read straight from `/recurring/summary` — do not
   re-derive them client-side from the list.
4. Table rows per frame ①: monogram, label, CategoryChip, cadence, amount, next date, StatusPill.
   **Amounts here are neutral `#EDF1F7`, not signed red** — they are expected charges, not ledger
   entries, and the money rule's sign colouring would state something false about them. The
   detail view's occurrence rows *are* real transactions and stay red.
   The Statut column is **empty for a healthy subscription** — no "OK" pill.
5. Price increase and missed charge render as amber StatusPills; a cancelled row is dimmed to
   .55 with a gray pill and no next date. Informative, not alarming (§9: never punitive).
6. Kebab actions: Confirmer / Ignorer / Marquer comme résilié / Modifier. A 409 from an illegal
   transition surfaces as a plain message, not a crash — the UI should not offer illegal
   transitions, but must not assume it never will.
7. Detail view per frame ②: header with the series stats and the account it belongs to, the
   amber increase banner **including the annualised impact** (« soit +24,00 € par an » — derive
   it from `price_change_minor` × occurrences per year for the cadence), and the occurrence
   history joined to its transactions with the stepped-up row marked. The user is being asked to
   trust a deduction, so the evidence is part of the screen, not a detail.
8. Manual creation modal per frame ④ (nom, compte, montant, cadence, catégorie) — `Irrégulier`
   selectable here only.
9. One empty state, per frame ③: explains the three-repeat rule, CTA « Aller aux imports » —
   more history is the actual remedy, so the CTA goes there rather than to manual creation.
10. A « Détecter » action triggering `POST /recurring/detect` with a result toast.
11. ARB fr + en, including the EN strings frame ⑤ pins (Monthly/Quarterly/Yearly, "Missed charge ·
    9 days late", "Cancelled · last charge Mar 18, 2026"); `flutter analyze` clean.

## Acceptance
- The panel is reachable from the sidebar with correct active treatment, on the standard chrome.
- Burden, counts, and amounts are locale-formatted and correct; list amounts are neutral.
- Signals render per frame ①; the Statut column is empty for healthy rows; cancelled rows dim.
- Lifecycle actions persist and refresh the list.
- Detail shows the occurrence history and the annualised impact of an increase.
- Manual creation works and offers `Irrégulier`, which detection never produces.
- The empty state renders with the imports CTA; fr + en parity.

## Tests
- Controller (mocked repo): load list + summary; status filter; transition patch updates the row;
  409 surfaces as an error state without losing the list; detect refreshes; annualised-impact
  math for each cadence.
- Widget: row renders cadence, neutral amount, next date; price-increase and missed pills render;
  healthy row has no pill; cancelled row dims; kebab offers only legal transitions for the
  current status; empty state; fr + en.

## Commits
- `feat(recurring): add subscriptions repository and controller`
- `feat(recurring): add subscriptions panel with burden summary and signals`
- `feat(recurring): add series detail and manual subscription creation`
