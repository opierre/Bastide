# 15 — Synthèse

Everything below is exactly what the mockup frames `15-Synthèse — *` in the Patrimoine mockup canvas show. Colors, amounts, order and positions are normative — do not invent. Tokens per `00-shared-design-block.md`.

## Concept (binding)
Net worth = accounts + held share of declared properties − outstanding loan principal. It is a **neutral figure even when positive or negative** (exactly like dashboard « Net »), displayed with a leading `−` (U+2212) when negative. Property values are **held flat at their declared value**: the 12-month series only moves through accounts and loans, and the panel says so inline. What is deliberately **not counted** — objectifs, abonnements — is stated in the panel, one quiet line each. The property list lives here.

## Nav
« Synthèse » / **"Net worth"** (`/networth`), last of « Patrimoine ». (EN: the existing « Aperçu » group is already "Overview"; the brief's "Overview" for this item collided, "Net worth" was chosen in review.) Icon: pie — full disc with one separated 90° sector, 1.5 px stroke, 2 px active.

## Top bar (this panel)
Title « Synthèse » / "Net worth" + descriptor « Ce que vous possédez, ce que vous devez » / "What you own, what you owe". Right: secondary « Nouveau bien » / "New property", user pill.

## Panel head
SegmentedControl **Synthèse | Biens (2)** (same recipe as 08 rules), margin-bottom 16; the count follows reality (« Biens (0) » in ④). Absent in ⑤ (nothing to switch between).

## Synthèse view (frames ① fr · ⑥ en)
**Row 1** — grid `1.5fr 1fr 1fr`, gap 18:
- **Patrimoine net** hero (iris tint): label iris; value **282 670,79 €** Space Grotesk 32 neutral; delta pill 22 px **iris 14 % / iris** (not green: a net-worth move is not income) with up-triangle « +1 477,78 € »; caption « vs avril 2026 · comptes en hausse, capital remboursé — valeur des biens inchangée ».
- **Actif** 516 800,00 € (Space Grotesk 26) « Comptes 24 300,00 € · Biens 492 500,00 € ».
- **Passif** 234 129,21 € « 2 crédits · capital restant dû ».

**Row 2** — grid `minmax(0,1fr) minmax(0,2fr)` (amended from `1.5fr`: the series needs the width more than the composition's rows), gap 18, fills the middle:
- **Composition de l'actif** Card: sub « Comptes par type, biens par nature »; HorizontalBars as one 10 px stacked strip (gap 2, radius 5) + legend rows 38 px (10 px hue square · label · percent `#5A6579` · value 600 right): Comptes courants `#5AA9FF` 2,3 % 11 800,00 € · Livret A `#2DD4BF` 2,4 % 12 500,00 € · Résidence principale `#4FD1E8` 81,3 % 420 000,00 € · Locatif (part détenue) `#A3E635` 14,0 % 72 500,00 €. Foot 11 `#5A6579` « Les biens comptent pour la part détenue seulement (Studio Villeurbanne : 72 500,00 € sur 145 000,00 €). » The 11 800 / 12 500 split of the 24 300,00 € is *mock, à fournir*.
- **Patrimoine net** Card: sub « Comptes et crédits, mois après mois », range right « juin 2025 → mai 2026 », then a 216 px AppSegmented « 12 mois · 3 ans · Tout » (default 12 mois; counted back from the series' last month). AreaLine (iris 2 px line, iris 10 % area, 2.5 px ring dots, 4 px on the last month), y grid at min / mid / max (268 k€ · 275 k€ · 283 k€), x labels juin … mai. Months without data are absent (no zero). (Amended — hovering a month rings its point and shows an overlay tooltip with the month, its net worth, and « Montants déclarés » when the month was declared, as on the dashboard's « Évolution de l'épargne ».) Under the chart an **info InlineBanner** (blue `#5AA9FF` 9 % / 30 % border, info glyph, 11.5 `#EDF1F7`): « Les biens sont maintenus à leur valeur déclarée (estimation la plus ancienne : 12/01/2026) : seuls les comptes et les crédits bougent d'un mois à l'autre. Les mois sans donnée sont simplement absents. » The 12 account balances behind the series are *mock, à fournir*; loan balances follow the schedules of 12.

**Row 3** — « VOLONTAIREMENT NON COMPTÉ » Card (padding 16/22), 3 columns, label 12.5/600 + why 11.5 `#97A3B6`:
Objectifs « Une allocation étiquette de l'argent déjà présent sur un compte — le compter reviendrait à le compter deux fois. » · Abonnements « Un prélèvement récurrent est une dépense à venir, pas une dette due aujourd'hui. »

## ④ aucun bien — synthèse sur les seuls comptes
Segmented « Biens (0) ». Hero **−209 829,21 €** (neutral, U+2212), same delta pill; Actif 24 300,00 € « Comptes 24 300,00 € · aucun bien déclaré »; composition strip with the two account rows only, plus a dashed plate « Aucun bien déclaré : l'actif ne compte que vos comptes. **Nouveau bien →** »; series recomputed on accounts − loans (same caveat banner); row 3 unchanged.

## Biens view (frame ②)
Grid 3 columns, gap 18: two **PropertyCards** + a dashed « + Nouveau bien » tile (« Résidence, locatif, terrain ou autre »).
PropertyCard (padding 18/22, hover iris border): name Space Grotesk 16 · nature CategoryChip-style pill (Résidence principale cyan `#4FD1E8` with house glyph · Locatif `#A3E635` with two-building glyph) · ⋯ overflow; **held value** Space Grotesk 24 + caption; then a 12 px key/value list: Quote-part · Prix d'acquisition · Depuis l'acquisition. (The frame's locatif « Loyer annuel · Régime » rows were dropped with the tax feature.)

| | Appartement Lyon 3e | Studio Villeurbanne |
|---|---|---|
| Held value / caption | 420 000,00 € / « valeur déclarée · estimée le 12/01/2026 » | **72 500,00 €** / « part détenue · sur 145 000,00 € estimés le 05/03/2026 » |
| Quote-part | 100 % | 50 % (indivision) |
| Prix d'acquisition | 385 000,00 € · 01/09/2023 | 132 000,00 € · 14/06/2021 |
| Depuis l'acquisition | 35 000,00 € au-dessus | 6 500,00 € au-dessus (part) |

Overflow menu (drawn open on the studio): Modifier · Nouvelle estimation · **Archiver**. (The frame's amber sub-line about the IFI base and the « Ces biens dans votre estimation d'impôt » card below the grid were dropped with the tax feature.)
Below the grid: foot link (archive-box icon) « Afficher les biens archivés (0) ».

## Modal nouveau bien (frame ③, over the list)
620 px Modal: « Nouveau bien », sub « La valeur déclarée entre dans la synthèse. » Grid 2 columns: Libellé « Studio Villeurbanne » · Nature (Select « Locatif ») · Valeur déclarée 145 000,00 € · Date d'estimation 05/03/2026 · Quote-part détenue 50 % (label carries « part : 72 500,00 € » live) · Prix d'acquisition · date (132 000,00 € | 14/06/2021, paired fields). Footer « Annuler » · gradient « Ajouter le bien ». (The frame's « Location » block — rent, régime, deductible charges — was dropped with the tax feature.)

## Empty state (frame ⑤)
No segmented control. Centered EmptyState: 64 px iris plate with pie glyph; « Rien à additionner pour l'instant »; « Importez un compte ou déclarez un bien : la synthèse additionne ce que vous possédez et soustrait vos crédits, sans rien inventer entre les deux. »; secondary « Importer un fichier » + gradient « Nouveau bien ».

## States to show
① synthèse (fr) ② liste des biens (fr) ③ modal nouveau bien (fr) ④ aucun bien — synthèse sur les seuls comptes (fr) ⑤ vide (fr) ⑥ synthèse (en).

## Notes
- Delta = this month's net minus last month's; pill is iris in both directions (triangle rotated 180° when negative), never green/red.
- Series point for a month = account balances at month end + flat property held shares − loan balances after that month's instalments; a month with no account snapshot is skipped, not zeroed.
- **Declared history** (amendment, 2026-10): for months before the first import, the user can declare the month-end total of all accounts; it stands in for the account balances in that month's point. The ledger always wins on a month it covers, and the two are never added. A segment touching a declared month is drawn **dashed** (5 on / 4 off, the `DashedBorder` rhythm, same iris 2 px); when the shown range holds one, a legend under the chart reads « — Comptes importés · - - Montants déclarés ». An iris text link « Historique déclaré » sits bottom-right of the card on every state, empty series included.
- **« Historique déclaré » modal** (560 px): sub « Le total de tous vos comptes à la fin d'un mois, pour la période avant vos imports. Un mois couvert par vos imports garde le chiffre importé. »; one row Mois (130 px, « MM/AAAA ») · Total des comptes (MoneyField, negative allowed) · gradient « Enregistrer » (adds or replaces the month); then the list newest first, 48 px rows: month « mars 2025 », neutral chip « Couvert par vos imports » when the ledger has that month, neutral amount, edit and delete icon buttons. Only an ended month can be declared. Footer: « Fermer ».
- **What existed that month** (amendment, 2026-10): a property counts in a series point only from its acquisition month (`acquired_on`; one without that date counts all along), and a loan only from the month before its first instalment, when it is paid out. Otherwise the down payment is counted twice before the purchase: as cash still in the accounts and inside property − loan. The caveat banner now reads « Les biens sont maintenus à leur valeur déclarée (estimation la plus ancienne : {date}) et ne comptent qu'à partir de leur date d'acquisition, les crédits qu'à partir de leur déblocage. Les mois sans donnée sont simplement absents. »
- Over 12 months, x labels stop sitting under each point: up to 12 evenly spaced months, labelled « janv. 24 ».
- Archiving keeps the property's history and removes it from actif as of the archive date. Archived properties are listed via the foot link and can be unarchived.
- « Nouvelle estimation » appends a dated value; « estimée le … » always shows the latest; the caveat banner names the **oldest** current estimate across properties.
- Rejected: a Donut for composition (four slices where two are ~2 % reads as an error), and any back-dated property valuation in the series.
