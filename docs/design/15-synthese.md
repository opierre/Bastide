# 15 — Synthèse (Phase 3)

Everything below is exactly what the mockup frames `15-Synthèse — *` in `FinStride Phase 3 Mockups.dc.html` show. Colors, amounts, order and positions are normative — do not invent. Tokens per `00-shared-design-block.md`.

## Concept (binding)
Net worth = accounts + held share of declared properties − outstanding loan principal. It is a **neutral figure even when positive or negative** (exactly like dashboard « Net »), displayed with a leading `−` (U+2212) when negative. Property values are **held flat at their declared value**: the 12-month series only moves through accounts and loans, and the panel says so inline. What is deliberately **not counted** — objectifs, abonnements, impôt estimé — is stated in the panel, one quiet line each. The property list lives here; editing a property here changes a tax figure (IFI base, revenus fonciers), and the UI says so where it happens.

## Nav
« Synthèse » / **"Net worth"** (`/networth`), last of « Patrimoine ». (EN: the existing « Aperçu » group is already "Overview"; the brief's "Overview" for this item collided, "Net worth" was chosen in review.) Icon: pie — full disc with one separated 90° sector, 1.5 px stroke, 2 px active.

## Top bar (this panel)
Title « Synthèse » / "Net worth" + descriptor « Ce que vous possédez, ce que vous devez » / "What you own, what you owe". Right: secondary « Nouveau bien » / "New property", user pill.

## Panel head
SegmentedControl **Synthèse | Biens (2)** (same recipe as Impôts / 08 rules), margin-bottom 16; the count follows reality (« Biens (0) » in ④). Absent in ⑤ (nothing to switch between).

## Synthèse view (frames ① fr · ⑥ en)
**Row 1** — grid `1.5fr 1fr 1fr`, gap 18:
- **Patrimoine net** hero (iris tint): label iris; value **282 670,79 €** Space Grotesk 32 neutral; delta pill 22 px **iris 14 % / iris** (not green: a net-worth move is not income) with up-triangle « +1 477,78 € »; caption « vs avril 2026 · comptes en hausse, capital remboursé — valeur des biens inchangée ».
- **Actif** 516 800,00 € (Space Grotesk 26) « Comptes 24 300,00 € · Biens 492 500,00 € ».
- **Passif** 234 129,21 € « 2 crédits · capital restant dû ».

**Row 2** — grid `minmax(0,1fr) minmax(0,1.5fr)`, gap 18, fills the middle:
- **Composition de l'actif** Card: sub « Comptes par type, biens par nature »; HorizontalBars as one 10 px stacked strip (gap 2, radius 5) + legend rows 38 px (10 px hue square · label · percent `#5A6579` · value 600 right): Comptes courants `#5AA9FF` 2,3 % 11 800,00 € · Livret A `#2DD4BF` 2,4 % 12 500,00 € · Résidence principale `#4FD1E8` 81,3 % 420 000,00 € · Locatif (part détenue) `#A3E635` 14,0 % 72 500,00 €. Foot 11 `#5A6579` « Les biens comptent pour la part détenue seulement (Studio Villeurbanne : 72 500,00 € sur 145 000,00 €). » The 11 800 / 12 500 split of the 24 300,00 € is *mock, à fournir*.
- **Patrimoine net · 12 mois** Card: sub « Comptes et crédits, mois après mois », range right « juin 2025 → mai 2026 ». AreaLine (iris 2 px line, iris 10 % area, 2.5 px ring dots, 4 px on the last month), y grid at min / mid / max (268 k€ · 275 k€ · 283 k€), x labels juin … mai. Months without data are absent (no zero). Under the chart an **info InlineBanner** (blue `#5AA9FF` 9 % / 30 % border, info glyph, 11.5 `#EDF1F7`): « Les biens sont maintenus à leur valeur déclarée (estimation la plus ancienne : 12/01/2026) : seuls les comptes et les crédits bougent d'un mois à l'autre. Les mois sans donnée sont simplement absents. » The 12 account balances behind the series are *mock, à fournir*; loan balances follow the schedules of 12.

**Row 3** — « VOLONTAIREMENT NON COMPTÉ » Card (padding 16/22), 3 columns, label 12.5/600 + why 11.5 `#97A3B6`:
Objectifs « Une allocation étiquette de l'argent déjà présent sur un compte — le compter reviendrait à le compter deux fois. » · Abonnements « Un prélèvement récurrent est une dépense à venir, pas une dette due aujourd'hui. » · Impôt estimé « Une estimation n'est pas un passif tant que l'avis n'est pas arrivé ; elle vit dans Impôts. »

## ④ aucun bien — synthèse sur les seuls comptes
Segmented « Biens (0) ». Hero **−209 829,21 €** (neutral, U+2212), same delta pill; Actif 24 300,00 € « Comptes 24 300,00 € · aucun bien déclaré »; composition strip with the two account rows only, plus a dashed plate « Aucun bien déclaré : l'actif ne compte que vos comptes. **Nouveau bien →** »; series recomputed on accounts − loans (same caveat banner); row 3 unchanged.

## Biens view (frame ②)
Grid 3 columns, gap 18: two **PropertyCards** + a dashed « + Nouveau bien » tile (« Résidence, locatif, terrain ou autre »).
PropertyCard (padding 18/22, hover iris border): name Space Grotesk 16 · nature CategoryChip-style pill (Résidence principale cyan `#4FD1E8` with house glyph · Locatif `#A3E635` with two-building glyph) · ⋯ overflow; **held value** Space Grotesk 24 + caption; then a 12 px key/value list: Quote-part · Prix d'acquisition · Depuis l'acquisition · (locatif) Loyer annuel (part) · Régime.

| | Appartement Lyon 3e | Studio Villeurbanne |
|---|---|---|
| Held value / caption | 420 000,00 € / « valeur déclarée · estimée le 12/01/2026 » | **72 500,00 €** / « part détenue · sur 145 000,00 € estimés le 05/03/2026 » |
| Quote-part | 100 % | 50 % (indivision) |
| Prix d'acquisition | 385 000,00 € · 01/09/2023 | 132 000,00 € · 14/06/2021 |
| Depuis l'acquisition | 35 000,00 € au-dessus | 6 500,00 € au-dessus (part) |
| Loyer · Régime | — | 3 900,00 € · Micro-foncier |

Overflow menu (drawn open on the studio): Modifier · Nouvelle estimation · **Archiver** with an amber 10.5 px sub-line « Sort aussi de la base IFI et des revenus fonciers. » — the warning is shown before the click, on the item itself; the confirm dialog repeats it.
Below: **« Ces biens dans votre estimation d'impôt »** Card — sub « Base IFI et revenus fonciers sont calculés ici et lus par Impôts — les modifier ici modifie l'estimation. », gray StatusPill « IFI : non redevable », link « Voir Impôts → ». Left list: Résidence principale, après abattement de 30 % 294 000,00 € · Studio Villeurbanne, part détenue 72 500,00 € · Capital restant dû du crédit immobilier −222 542,70 € · **Base IFI 143 957,30 €**. Right: « Base 143 957,30 € » ⟷ « Seuil 1 300 000,00 € », 8 px bar iris 11,1 %, note « La base atteint 11 % du seuil. Les revenus fonciers déclarés depuis le studio (3 900,00 €, micro-foncier) alimentent aussi l'estimation. » Foot link (archive-box icon) « Afficher les biens archivés (0) ».

## Modal nouveau bien, régime réel (frame ③, over the list)
620 px Modal: « Nouveau bien », sub « La valeur déclarée entre dans la synthèse et dans la base IFI ; le loyer entre dans l'estimation d'impôt. » Grid 2 columns: Libellé « Studio Villeurbanne » · Nature (Select « Locatif ») · Valeur déclarée 145 000,00 € · Date d'estimation 05/03/2026 · Quote-part détenue 50 % (label carries « part : 72 500,00 € » live) · Prix d'acquisition · date (132 000,00 € | 14/06/2021, paired fields). **Location block** (border-top, shown only for Locatif): « Location » 13/700 + « affiché pour un bien locatif »; 3 columns: Loyer annuel (part) 3 900,00 € · Régime SegmentedControl Micro-foncier | **Réel** · Charges déductibles **1 240,00 €** (focused; label pill « RÉEL ») — this field exists **only** under Réel. Help 11.5 `#5A6579` « Au réel, le revenu foncier net = loyer − charges déductibles ; en micro-foncier, l'abattement de 30 % s'applique et les charges n'entrent pas. » Footer « Annuler » · gradient « Ajouter le bien ». The 1 240,00 € charges value is *mock, à fournir*.

## Empty state (frame ⑤)
No segmented control. Centered EmptyState: 64 px iris plate with pie glyph; « Rien à additionner pour l'instant »; « Importez un compte ou déclarez un bien : la synthèse additionne ce que vous possédez et soustrait vos crédits, sans rien inventer entre les deux. »; secondary « Importer un fichier » + gradient « Nouveau bien ».

## States to show
① synthèse (fr) ② liste des biens (fr) ③ modal nouveau bien, régime réel (fr) ④ aucun bien — synthèse sur les seuls comptes (fr) ⑤ vide (fr) ⑥ synthèse (en).

## Notes
- Delta = this month's net minus last month's; pill is iris in both directions (triangle rotated 180° when negative), never green/red.
- Series point for a month = account balances at month end + flat property held shares − loan balances after that month's instalments; a month with no account snapshot is skipped, not zeroed.
- Archiving keeps the property's history and removes it from actif, from the IFI base and from revenus fonciers as of the archive date; the confirm Modal (not drawn — the menu hint carries the warning per review) repeats the amber sentence. Archived properties are listed via the foot link and can be unarchived.
- « Nouvelle estimation » appends a dated value; « estimée le … » always shows the latest; the caveat banner names the **oldest** current estimate across properties.
- Rejected: a Donut for composition (four slices where two are ~2 % reads as an error), and any back-dated property valuation in the series.
