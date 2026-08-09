# P2-09 — Settings frontend: local AI
Scope: frontend
Depends on: P2-01, P2-03
Skills: flutter-frontend, design-system, i18n-l10n, testing
PROJECT.md: §4b, §5b, §9
Design: `docs/design/09-settings.md` "Phase 2 amendment — IA locale (tab Données)", frames
③–④ — normative

## Objective
An « IA locale » grouped Card in Settings → **Données** where the user enables AI, points the app
at their runtime, picks a model, sets the confidence threshold, and tests the connection.

> The card lives in **Données, not Préférences** — the drawn frames put it there, alongside the
> database location and export. Préférences (Langue, Devise, Formats) is unchanged.

## Files
- `frontend/lib/features/settings/presentation/{settings_screen.dart,ai_settings_card.dart}` (edit + new)
- `frontend/lib/features/settings/application/settings_controller.dart`
- `frontend/lib/features/settings/data/settings_repository.dart`
- `frontend/lib/features/settings/domain/user_settings.dart`
- ARB keys (fr+en); `frontend/test/features/settings/...`

## Contract slice
```
GET   /api/v1/settings                  → user_settings
PATCH /api/v1/settings                  {ai_enabled?, inference_base_url?, model_tag?,
                                         confidence_threshold?}
GET   /api/v1/settings/inference/health → {reachable, models, detail?}
```

## Steps
1. Repository + controller for settings and the health probe. The controller owns the connection
   state — *disabled*, *reachable*, *unreachable* — as one enum, so the card can't render a
   contradictory combination.
2. Card per frames ③–④, in this order: header row (title + « Activer la catégorisation par IA »
   + Toggle) · **privacy callout** · address + model field row · threshold Slider · status row
   behind a divider with « Tester la connexion ». The privacy callout is the card's centerpiece
   and is visible whenever the card is — it is not conditional on the toggle.
3. Model field: a Select populated from the probe's list, with manual entry allowed (« Liste
   fournie par le moteur — saisie manuelle possible. »). When no engine answers it becomes the
   dashed read-only « — » with « Aucun modèle — moteur injoignable. » — never an empty dropdown
   the user is trapped behind.
4. Threshold is the `Slider` component added in 00 §Phase 2 (not a text field), labelled with its
   live percentage.
5. Probe on: card mount, base-URL change (debounced), and the explicit test button. Show the
   probe's own progress on the button, not a blocking overlay.
6. Patch on change with a debounce; surface a validation error from the backend inline on the
   field it belongs to — the loopback-only URL rule (P2-01) is a 422 the user must be able to
   understand and fix, so the message must explain *why* a remote host is refused.
7. Threshold presented as a percentage in the UI, stored as the `[0,1]` real the API expects —
   convert at the edge, like money and dates (flutter-frontend skill). It drives the 07 review
   queue directly, so a change here must be reflected the next time a run classifies.
8. Turning the toggle off returns the 07 queue to its Phase 1 rendering with the calm invitation
   (P2-08 step 6) — verify that end to end, not just that the field persisted.
9. ARB keys fr + en; `flutter analyze` clean.

## Acceptance
- The card renders in the **Données** tab; Préférences is unchanged.
- Both drawn states render as specified: connected (green dot, model count) and no engine (amber
  dot, « En savoir plus », dashed model field).
- The privacy callout is present whenever the card is, toggle on or off.
- Enabling AI, setting a URL and model, and moving the threshold Slider all persist and survive a
  reload.
- The model Select lists what the probe returned and still allows a manual tag.
- A rejected non-loopback URL shows an inline, explanatory message.
- The threshold round-trips correctly between the percentage shown and the `[0,1]` stored.
- fr + en parity; no hard-coded strings.

## Tests
- Controller (mocked repo): load → defaults; patch debounce; probe success/failure maps to the
  right state; threshold conversion both directions.
- Widget: both connection states render their treatment; privacy callout always present; model
  field degrades to the dashed read-only form when unreachable; test button triggers a probe;
  validation error renders on the URL field; fr + en.

## Commits
- `feat(settings): add settings repository and controller`
- `feat(settings): add local AI configuration card with runtime connection test`
