# P2-14 — Goals frontend & dashboard integration
Scope: frontend
Depends on: P2-13
Skills: flutter-frontend, design-system, i18n-l10n, testing
PROJECT.md: §5b, §9, §13
Design: `docs/design/11-goals.md` (frames ①–⑤) and `04-dashboard.md` "Row 3 — Phase 2" — both
normative

## Objective
The Objectifs panel — goal cards with progress, allocation flow, allocation history, the reached
state, archiving, and the over-allocation banner — plus the Objectifs card in the dashboard's
re-split row 3.

## Files
- `frontend/lib/features/goals/presentation/{goals_screen,goal_card,goal_detail,goal_form_modal,allocation_modal}.dart`
- `frontend/lib/features/goals/application/goals_controller.dart`
- `frontend/lib/features/goals/data/goals_repository.dart`
- `frontend/lib/features/goals/domain/{goal,goal_allocation}.dart`
- `frontend/lib/features/dashboard/presentation/goals_progress_card.dart`
- `frontend/lib/core/navigation/sidebar_controller.dart` + `core/router/app_router.dart` — edit
- ARB keys (fr+en); `frontend/test/features/goals/...`

## Steps
1. Add the « Objectifs » sidebar item (Gestion group, last; flag icon) and its route, per the
   Phase 2 nav amendment in frame 00, keeping the fixed chrome.
2. Repository + controller: list (with status filter), create/patch/archive/restore, allocations
   list/create/delete.
3. **No account appears anywhere** in this feature — not on a card, not in the detail header, not
   in the allocation modal. `11-goals.md`'s Concept section is binding on this point.
4. Grid state per frame ①, top to bottom: the reassurance lock line « Répartition sur le
   papier… », the over-allocation banner when applicable, the 2-column GoalCard grid, then the
   « Afficher les objectifs archivés (N) » link which reveals dimmed archived cards in place.
5. GoalCard: name, date-or-reached pill, saved/target value line, 8 px progress bar, percent.
   Progress is **clamped to 100 % for the bar** while the percent text reports the real figure —
   a bar drawn past full reads as a rendering bug, but hiding over-funding would be a lie about
   the user's money. Reached: green percent, green check pill, tinted card.
6. Detail view per frame ②: 96 px progress ring (same recipe as SavingsRateCard), « Archiver »
   secondary + « Nouvelle allocation » primary, the reassurance line, then the allocation history
   — one list, signed amounts, green + / red −, with the foot note that no transaction is created.
7. Allocation modal per frame ③: montant (« Un montant négatif retire de l'objectif. »), date,
   optional note. **One signed amount field — no separate deposit/withdraw modes.** Two verbs
   over one mechanism would invite the user to expect two histories.
8. Over-allocation banner when total allocations exceed the user's savings-account balances:
   informative and dismissible, never blocking (§13). Compute it in the controller from accounts
   already loaded — do not add an endpoint for it.
9. Archiving: from the detail header; an archived goal leaves the grid and the dashboard card,
   keeps its history, and can be restored from the archived list. Reached goals are **not**
   auto-archived — the user decides.
10. Dashboard: row 3 re-splits to `1fr .95fr .85fr` (frame `04-Dashboard — avec carte objectifs`)
    and gains the iris-tinted Objectifs card — top 3 active goals, compact rows, « Voir tout »
    link, **hidden entirely when no goals exist**. Existing row-3 cards keep their content; only
    the split changes.
11. Empty state per frame ④ with the « Nouvel objectif » CTA; ARB fr + en; `flutter analyze` clean.

## Acceptance
- The panel is reachable from the sidebar with the standard chrome.
- No account is displayed anywhere in the feature.
- Progress ring/bar and amounts are correct and locale-formatted; the bar clamps at 100 % while
  the text reports the true percentage.
- Allocating and withdrawing both work through one signed flow and update progress immediately.
- Allocation history lists and deletes correctly.
- Reaching a target renders the reached state without interrupting the user; it does not archive.
- Archive removes the goal from the grid and the dashboard card; restore brings it back.
- Over-allocation warns, never blocks.
- The dashboard Objectifs card renders the top 3 active goals, hides when there are none, and
  row 3 keeps its other two cards intact.
- fr + en parity.

## Tests
- Controller (mocked repo): load; create; allocate (positive and negative) updates progress;
  delete allocation recomputes; archive/restore transitions; over-allocation flag derives
  correctly from loaded data.
- Widget: card renders progress and amounts for fr + en; over-funded goal clamps the bar and
  reports the true text; reached card renders its green treatment; allocation modal submits a
  negative amount; archived link shows the count and reveals dimmed cards; empty state;
  dashboard card renders the top 3 and is absent with zero goals.

## Commits
- `feat(goals): add goals repository and controller`
- `feat(goals): add goals panel with progress cards and allocation flow`
- `feat(dashboard): add goals progress card`
