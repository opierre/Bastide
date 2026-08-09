# P2-08 — Review queue: AI suggestions & run progress
Scope: frontend
Depends on: P2-05, P2-06, P2-07
Skills: flutter-frontend, ai-categorization, design-system, i18n-l10n, testing
PROJECT.md: §5b, §7, §9
Design: `docs/design/07-transactions.md` "Phase 2 amendment — AI proposals in the review queue"
(frames ⑥–⑨) and `00-shared-design-block.md` §Phase 2 additions — both normative

## Objective
Surface stage 2 in the transactions panel: model proposals with their confidence in the review
queue, the "toujours catégoriser ainsi" affordance that creates a rule, and a calm run-progress
banner. When AI is off the panel must render exactly as in Phase 1 plus one quiet invitation.

## Files
- `frontend/lib/features/transactions/presentation/review_queue.dart` — edit
- `frontend/lib/features/transactions/presentation/{ai_run_banner,always_categorize_modal}.dart`
- `frontend/lib/core/widgets/{proposed_category_chip,confidence_gauge}.dart` — new shared
  widgets, per 00 §Phase 2 additions
- `frontend/lib/features/categorization/{data/categorization_repository,application/run_controller}.dart`
- `frontend/lib/features/transactions/application/transactions_controller.dart` — edit
- ARB keys (fr+en); `frontend/test/features/{transactions,categorization}/...`

## Contract slice
```
POST /api/v1/categorization/runs      {account_id?, scope} → 202 run
GET  /api/v1/categorization/runs/{id} → run
POST /api/v1/categorization/runs/{id}/cancel
POST /api/v1/rules/preview            {…} → {match_count, samples}
POST /api/v1/rules/from-transaction   {…} → {rule, recategorized_count}
GET  /api/v1/settings                  → {ai_enabled, …}
GET  /api/v1/settings/inference/health → {reachable, models}
```

## Steps
1. Run controller: start a run, poll `GET /runs/{id}` while `pending`/`running`, expose progress,
   stop polling on a terminal status. **Poll at ~2 s and stop when the panel is disposed** — a
   timer that outlives its screen keeps a dead sidecar conversation alive forever.
2. Queue header Card (iris-tint): « 12 transactions à vérifier » with the count the AI proposed
   for, and the resolved-progress bar. While a run is active this Card is **replaced** by the
   running banner — spinner, « Catégorisation en cours — 84 sur 213 transactions », the
   classées/à-vérifier sub-line, « Annuler », and the progress bar. The list stays interactive
   beneath it; nothing blocks.
3. Terminal states: a run that ended `partial` shows the dismissible amber banner
   « Catégorisation terminée — 12 transactions n'ont pas pu être analysées. » with its « Voir »
   link. `failed` reports plainly. Neither is an error wall.
4. Review queue rows gain `ProposedCategoryChip` (dashed, category hue — distinct from both an
   assigned chip and the neutral dashed « Non catégorisé ») plus `ConfidenceGauge` and
   « Confiance NN % », shown only for rows carrying a model proposal. Two actions per row:
   **Confirmer** (assigns the proposal, `source=user`, clears the flag) and **Corriger** (opens
   the standard category picker). A row with no proposal keeps its Phase 1 anatomy plus the
   italic « — aucune proposition » and the « Choisir une catégorie » link.
   Confidence renders as a **percentage**, never the raw `[0,1]` float the API returns — convert
   at the edge like money and dates.
5. « Toujours catégoriser ainsi » modal (frame ⑧): pre-filled champ/condition/motif from P2-06's
   suggestion, target category, the « Appliquer aux transactions existantes » checkbox, and the
   live match count from `POST /rules/preview` in its info banner. On create →
   `POST /rules/from-transaction`, then the success toast « Règle créée · N transactions
   recatégorisées » and a list refresh. Reuse P2-07's preview and rule-form widgets rather than
   building a second editor — two rule forms that drift apart is exactly the bug this shares
   code to avoid.
6. **AI-off state (the default, and what most users see):** when `ai_enabled` is false or health
   reports unreachable, rows render Phase 1 style — no proposals, no gauges, no Confirmer/
   Corriger — plus the calm blue invitation at the Card foot linking to Paramètres. Nowhere else
   in the app nags about it.
7. Refresh the transaction list as a run progresses so rows leave the queue while the user
   watches, and confirm the panel stays usable during a run (no modal blocking).
8. ARB keys fr + en for every string above. `flutter analyze` clean.

## Acceptance
- Rows with a proposal show the dashed proposed chip, the gauge, and « Confiance NN % »; rows
  without one show « aucune proposition »; rule/user rows are untouched.
- Confirmer clears the review flag; Corriger assigns the chosen category — both set
  `source=user`.
- The rule modal previews its match count and, on create, reports how many rows it changed.
- The header Card is replaced by the running banner during a run and restored after; the list
  stays interactive throughout.
- `partial` shows the dismissible amber banner; `failed` reports plainly. Neither blocks.
- With AI off or the runtime down: no AI UI anywhere, one calm invitation, queue fully
  functional and identical to Phase 1.
- Confidence is displayed as a percentage, never a raw float.
- Polling stops on terminal status and on dispose.
- fr + en parity.

## Tests
- Run controller (mocked repo): polls until terminal then stops; cancel transitions; dispose
  cancels the timer (assert no further calls).
- Widget tests: proposed chip + gauge render for a proposed row and not for a rule row; the
  no-proposal row renders its own treatment; confirm/correct paths; rule modal submits the
  expected payload and renders the preview count; running banner replaces the header Card;
  `partial` banner dismissible; AI off renders the invitation and no AI controls; fr + en.

## Commits
- `feat(categorization): add run repository and polling controller`
- `feat(transactions): show model proposals and confidence in the review queue`
- `feat(transactions): add always-categorize rule creation from a correction`
- `feat(categorization): add run progress banner with cancellation`
