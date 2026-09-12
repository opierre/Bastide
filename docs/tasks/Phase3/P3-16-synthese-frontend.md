# P3-16 — Synthèse panel & properties management
Scope: frontend
Depends on: P3-05, P3-10, P3-11
Skills: flutter-frontend, design-system, i18n-l10n, testing
PROJECT.md: §18, §4c, §9
Design: `docs/design/15-synthese.md` + `00-shared-design-block.md` — both normative

## Objective
The Synthèse panel: assets against liabilities, net worth, the 12-month series with its caveat, and
the property list that feeds both this panel and the IFI base — properties are declared here,
because this is where a user thinks about what they own.

## Files
- `frontend/lib/features/networth/presentation/networth_screen.dart` (replace placeholder),
  `networth_summary_card.dart`, `networth_series_chart.dart`, `composition_breakdown.dart`
- `frontend/lib/features/properties/presentation/property_list.dart`, `property_form_modal.dart`,
  `property_card.dart`
- `frontend/lib/features/networth/application/networth_controller.dart`
- `frontend/lib/features/properties/application/properties_controller.dart`,
  `data/properties_repository.dart`, `domain/property.dart`
- ARB keys (fr + en); `frontend/test/features/networth/...`,
  `frontend/test/features/properties/...`

## Steps
1. Two controllers, one panel: net worth (read-only summary) and properties (CRUD). A property
   write invalidates the net-worth summary so the figure follows in the same interaction.
2. Summary: assets split into accounts and properties, liabilities from mortgages, and net worth.
   Net worth is a **neutral** figure like Net on the dashboard — never green when positive (00
   money rule) — while the delta against last month may carry semantic colour.
3. The series is an AreaLine per 00 §Components, and it **carries its caveat inline**: when
   `property_values_held_flat` is true, say that property values are held at their declared value
   and name `valued_on_oldest`. §18 forbids inventing a back-dated valuation, so the chart must not
   look like it knows one. Months the API omitted are simply absent — do not zero-fill them.
4. Composition: where the value sits (accounts by type, properties by kind) using the existing
   Donut or HorizontalBars recipe, not a new idiom.
5. **State what is deliberately not counted**, in the panel: goals (allocations label money already
   in an account), subscriptions and estimated tax (a future charge is not a debt). §18 makes these
   exclusions correct; an unexplained absence just reads as a missing feature.
6. Property list and form: label, kind, market value, valuation date, ownership share (percent to
   bps at the edge), optional acquisition price and date, and the rent block — rent, regime, and
   charges only under `reel`, matching P3-05's validation so the user is never refused by surprise.
7. Show each property's user share when ownership is below 100 %, and its valuation date with an
   « estimée le … » line: a declared value ages, and the panel should say how old it is.
8. A property archived from the list leaves the summary and the IFI base; say so at the
   confirmation, since the user is changing a tax figure from a net-worth screen.
9. Empty states: no properties (invite declaring one), and no data at all (the summary with only
   account balances still works — a user with one account and no property has a net worth).
10. ARB fr + en for every string, including the flat-valuation caveat and the exclusions.

## Acceptance
- Assets, liabilities and net worth render exactly as returned, locale-formatted and tabular; net
  worth is neutral-toned.
- The flat-property caveat appears whenever the API flags it, naming the oldest valuation date.
- Omitted months are absent from the chart, not plotted as zero.
- The exclusions (goals, subscriptions, tax) are stated in the panel.
- Property CRUD works; the rent/regime/charges rules are enforced in the form before the API;
  percent ownership converts to bps; the user share shows below 100 %.
- Archiving a property updates the summary in the same interaction and warns about the IFI base.
- A user with accounts but no properties gets a working summary; a user with nothing gets the empty
  state, not an error.
- fr + en parity; `flutter analyze` clean.

## Tests
- Controllers (mocked repos): summary mapping; a property write invalidating the summary; property
  CRUD; archive.
- Widget: summary figures and neutral net worth in fr and en; caveat shown and hidden per the flag;
  a gap month absent from the series; exclusions rendered; form validation matrix mirroring P3-05;
  ownership share display; archive confirmation mentioning the IFI base; both empty states.

## Commits
- `feat(properties): add the properties repository, controller and form`
- `feat(networth): add the synthese panel with assets, liabilities and net worth`
- `feat(networth): add the net-worth series with its valuation caveat`
