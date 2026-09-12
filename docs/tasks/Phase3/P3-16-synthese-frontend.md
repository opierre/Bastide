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
   Net worth is a **neutral** figure like Net on the dashboard — never green when positive, and a
   negative net worth keeps the neutral tone with a leading U+2212 (00 money rule). **The delta
   against last month is neutral too**: an iris 14 % / iris pill with the triangle rotated for
   direction, never semantic green or red (`15-synthese.md` §Concept, §Notes — a net-worth move is
   not income). This card's earlier prose said the delta may carry semantic colour; the frame
   overrides it.
3. The series is an AreaLine per 00 §Components, and it **carries its caveat inline**: when
   `property_values_held_flat` is true, say that property values are held at their declared value
   and name `valued_on_oldest`. §18 forbids inventing a back-dated valuation, so the chart must not
   look like it knows one. Months the API omitted are simply absent — do not zero-fill them.
4. Composition: where the value sits (accounts by type, properties by kind) as the **HorizontalBars
   recipe** — one stacked 10 px strip plus legend rows carrying label, percent and value. A Donut
   is explicitly rejected in the frame: four slices where two sit near 2 % reads as an error. The
   foot states that properties count for the **held share only**, naming the property and both
   figures.
5. **State what is deliberately not counted**, in the panel: goals (allocations label money already
   in an account), subscriptions and estimated tax (a future charge is not a debt). §18 makes these
   exclusions correct; an unexplained absence just reads as a missing feature.
6. Property list and form: label, kind, market value, valuation date, ownership share (percent to
   bps at the edge), optional acquisition price and date, and the rent block — rent, regime, and
   charges only under `reel`, matching P3-05's validation so the user is never refused by surprise.
7. Show each property's user share when ownership is below 100 %, and its valuation date with an
   « estimée le … » line: a declared value ages, and the panel should say how old it is.
8. A property archived from the list leaves the summary, the IFI base and the property income; say
   so **on the menu item itself**, in the amber tone, before the click — and repeat it in the
   confirmation, since the user is changing a tax figure from a net-worth screen. Archived
   properties stay reachable through a foot link and can be unarchived. « Nouvelle estimation »
   appends a dated value and the card always shows the latest with its « estimée le … » line.
8b. **The Biens view carries the « Ces biens dans votre estimation d'impôt » card** (`15-synthese.md`
   §Biens view): the IFI base built line by line — primary residence after its abattement, each
   held share, the linked mortgage's outstanding netted off — the base against the threshold with
   its bar, the liability StatusPill, and a link into Impôts. Every figure comes from the tax
   estimate's IFI component (P3-07 step 7), **not recomputed here**; if the estimate does not
   expose the base's components, stop and ask rather than deriving them in Dart.
9. Empty states: no properties — the summary still computes on accounts and loans alone, the
   composition strip shows only the account rows with a dashed invite plate, and the segmented
   control reads « Biens (0) » — and no data at all, which is the one case that drops the
   segmented control for a full EmptyState. A user with one account and no property has a net
   worth, and with two loans and no accounts it is legitimately negative.
10. ARB fr + en for every string, including the flat-valuation caveat and the exclusions.

## Acceptance
- Assets, liabilities and net worth render exactly as returned, locale-formatted and tabular; net
  worth is neutral-toned in both directions, and the month delta pill is iris, never green or red.
- The composition is a stacked HorizontalBars strip with its held-share foot note; no Donut.
- The IFI base card in the Biens view renders from the estimate's components, not from local sums.
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
- Widget: summary figures and neutral net worth in fr and en, including a negative net worth with
  U+2212; the delta pill iris in both directions; caveat shown and hidden per the flag; a gap month
  absent from the series; exclusions rendered; form validation matrix mirroring P3-05, including
  the charges field appearing only under `reel`; ownership share display and the live held-share
  label in the form; the archive menu item carrying its warning before the click and the
  confirmation repeating it; the IFI base card from a fixture; both empty states.

## Commits
- `feat(properties): add the properties repository, controller and form`
- `feat(networth): add the synthese panel with assets, liabilities and net worth`
- `feat(networth): add the net-worth series with its valuation caveat`
