# Claude Design prompt — Phase 3 « Patrimoine » panels

> **How to use.** Paste, in this order and nothing else: (1) `00-shared-design-block.md`
> **verbatim**, (2) `PROJECT.md` §15, §16, §17, §18 **verbatim**, (3) everything below the rule in
> this file. Then run it. The wrapper convention is `01-tool-wrappers.md`; this file is the Phase 3
> instance of it. Regenerating a single panel later means re-pasting (1) + (2) + only that panel's
> brief, and re-reading the amendment paragraphs first (see *Amendments survive regeneration*).

---

You are designing four new panels for **FinStride**, a dark-first, French-first desktop personal
finance app that already ships eleven panels. Everything you draw joins a running product: the
palette, typography, spacing, components, chrome and copy voice are **already decided** and are
given to you above as binding tokens. You are not redesigning the app. You are extending it.

Deliver in two stages, in this order, and stop for review between them.

**Stage 1 — mockups.** One canvas document, `FinStride Phase 3 Mockups.dc.html`, holding every
frame listed under each panel's *States to show*. Frames are 1440x900, named
`NN-Panel — variant (fr|en)` exactly as the existing sets are (`12-Crédits — liste (fr)`).
Propose the layouts; where a panel admits two honest readings, draw the one you argue for and say
in one line what you rejected and why.

**Stage 2 — panel description files.** After the frames are reviewed, write
`docs/design/12-credits.md`, `13-impots.md`, `14-simulateur.md`, `15-synthese.md`, plus a **Phase 3
additions** paragraph to append to `00-shared-design-block.md`. Their contract is at the end of
this prompt. They are *transcriptions of what you drew*, not fresh design prose: they become
normative for the Flutter build.

## Non-negotiable invariants

Break any of these and the frame is wrong, however good it looks.

1. **Fixed chrome.** 252 px sunken sidebar, 72 px top bar, **no bottom bar**, content padding
   24x28. Identical on all four panels and on every existing one.
2. **The new nav group.** « Patrimoine » / "Wealth" sits **after** « Gestion » and **before** the
   pinned « Paramètres » and its « Données 100 % locales » privacy badge. Four items in this order:
   **Crédits** (`/mortgages`) · **Impôts** (`/tax`) · **Simulateur** (`/simulations`) ·
   **Synthèse** (`/networth`). Group label in the same 10 px uppercase style as the other two.
3. **The sidebar stack must still breathe** at 900 px with 3 + 4 + 4 + 1 items at the existing
   40 px pill rhythm, plus the divider, Paramètres and the badge. If it cannot, **stop and say so
   instead of shrinking a token** — sidebar density is a decision for the product owner, not a
   drafting fix. Draw the collapsed 76 px rail once, with a hairline separator between each group.
4. **Icons** continue the existing language: 1.5 px stroke, round caps, 18 px, filled variant when
   active. Each must be distinguishable at 18 px from the dashboard 4-square, wallet, twin arrows,
   download tray, tag, cycle and flag already in the rail.
5. **Money rule.** Income green with `+`, expense red with `−` (U+2212), everything else neutral
   `#EDF1F7`. A mortgage instalment, a tax amount, a property value and a net worth are **neutral
   figures** — they are scheduled or declared amounts, not booked transactions. Net worth stays
   neutral even when positive, exactly as dashboard « Net » does. Tabular figures, right-aligned
   in columns, always.
6. **Rates are not money.** A percentage is 11 px–14 px neutral or iris, never green/red, and
   never carries a money sign. French formatting throughout: `3,45 %`, `1 195,07 €`, `14/05/2026`.
7. **No new component idioms.** Compose from the inventory in the shared block — Card, StatCard,
   DataTable, ChartContainer, AreaLine, StackedBars, Donut, HorizontalBars, SegmentedControl,
   FormField, Select, Slider, Toggle, StatusPill, InlineBanner, Modal, Toast, EmptyState,
   LoadingSkeleton, ErrorRetry, Button, monogram BrandLogo. A genuinely new element is allowed only
   if nothing in the inventory can carry the meaning; if you add one, name it and specify it fully
   in the Stage 2 files so it can be built.
8. **Monogram chips only** for lenders and institutions. Never a bank logo image.
9. **No emoji anywhere.** Line icons only.
10. **Film grain on the frame background only**, never as an overlay on cards, popovers or modals.
11. **Encouraging, never punitive.** This is the phase where the app talks about debt and tax — the
    two topics where a finance app most easily becomes scolding. A 42 % debt ratio is stated
    plainly with its reference point; it is never red-alarmed, never moralised, never framed as
    failure. Calm, factual, useful.
12. **Two statements must be visible, not hidden behind tooltips or expanders:** that an HCSF
    reading is informational and binds no lender (Crédits, Simulateur), and that a tax figure is an
    estimate with named gaps — not a return, not advice, no filing (Impôts). Design them as
    first-class content. `PROJECT.md` §15–§16 are explicit that these are part of the feature.
13. **fr sizes every box.** French copy is the layout constraint; English renders in the same
    geometry.

## Shared mock data — use these figures, unchanged

Same world as the existing mockups: **Camille Dubois**, `camille.dubois@proton.me`, EUR, current
month **mai 2026**, accounts BNP — Compte courant · Revolut · Livret A. Consistency across frames
matters more than realism in any one of them: a figure that appears on two panels must be the same
figure, because these frames become the spec.

**Loans**

| | Crédit immobilier | Prêt travaux |
|---|---|---|
| Libellé | Appartement Lyon 3e | Travaux cuisine |
| Prêteur (monogramme) | BNP `#2FB574` | Crédit Agricole `#0AA396` |
| Capital emprunté | 240 000,00 € | 15 000,00 € |
| Taux nominal | 3,45 % | 4,90 % |
| Assurance / mois | 28,80 € | — |
| Durée | 300 mois (25 ans) | 60 mois |
| 1re échéance | 01/09/2023 | 01/03/2025 |
| Frais de dossier | 1 450,00 € | 0,00 € |
| Mensualité (hors assurance) | 1 195,07 € | 282,38 € |
| Échéance totale | 1 223,87 € | 282,38 € |
| Capital restant dû (mai 2026) | 222 542,70 € | 11 586,51 € |
| Capital remboursé | 7,3 % | 22,8 % |
| Échéances restantes | 267 | 45 |
| Intérêts totaux | 118 521,00 € | 1 942,80 € |
| TAEG indicatif | 3,79 % | 5,01 % |
| Prochaine échéance | 01/06/2026 | 01/06/2026 |

Charge mensuelle totale **1 506,25 €** · capital restant dû total **234 129,21 €**.
Revenu mensuel **4 600,00 €**, source **déclaré** (le ménage perçoit des revenus hors application —
c'est précisément ce que l'override sert à dire). Taux d'endettement **32,7 %** (1 506,25 / 4 600), repère HCSF 35 % —
**sous le seuil**, donc l'état par défaut est sain. Le ménage médian du grand livre serait
2 850,00 €, soit 52,9 % : prévoir un état où `income_source = ledger` et un où il est `unknown`.

**Biens**

| | Résidence principale | Locatif |
|---|---|---|
| Libellé | Appartement Lyon 3e | Studio Villeurbanne |
| Nature | Résidence principale | Locatif |
| Valeur déclarée | 420 000,00 € | 145 000,00 € |
| Estimée le | 12/01/2026 | 05/03/2026 |
| Quote-part | 100 % | 50 % (indivision) |
| Part détenue | 420 000,00 € | 72 500,00 € |
| Prix d'acquisition | 385 000,00 € (01/09/2023) | 132 000,00 € (14/06/2021) |
| Loyer annuel (part) | — | 3 900,00 € |
| Régime | — | Micro-foncier |

**Profil fiscal 2025** — ménage **couple**, 1 personne à charge, **2,5 parts**. Salaires
64 200,00 € · dividendes 1 200,00 € · intérêts 320,00 € · plus-values 0 € · PFU (pas d'option
barème) · charges déductibles 0 € · crédits d'impôt 0 €.

**Estimation 2025** — revenu net imposable **60 510,00 €** · IR **3 494,43 €** · décote 0 €
(non applicable) · quotient non plafonné (avantage 989,53 € pour un plafond de 1 791,00 €) ·
taux moyen (IR / revenu net imposable) **5,8 %** · taux marginal **11 %** ·
PFU **456,00 €** (dont IR 194,56 € et PS 261,44 €) · foncier net **2 730,00 €** et PS **469,56 €** ·
**IFI : non redevable** (base 143 957,30 € contre un seuil de 1 300 000,00 €) ·
**total estimé 4 419,98 €**.

> Ces montants sont des **données de maquette**, cohérentes entre elles et suffisantes pour
> dimensionner les blocs. L'arithmétique fiscale appartient au moteur vérifié du backend
> (`PROJECT.md` §16, carte P3-07) : le fichier de description ne doit jamais être présenté comme la
> référence de calcul, seulement comme la référence **visuelle**. Dis-le dans les Notes du fichier.

**Simulation** — prix 320 000,00 € · apport 40 000,00 € · frais 4 500,00 € · emprunt
284 500,00 € · taux 3,25 % · 300 mois · assurance 32,00 €/mois → mensualité **1 386,41 €**,
échéance **1 418,41 €**, intérêts totaux **131 423,00 €**, assurance totale **9 600,00 €**,
coût total **145 523,00 €** (intérêts + assurance + frais), coût/prix **45,5 %**,
TAEG indicatif **3,67 %**. Taux d'endettement **30,8 %** seul,
**63,6 %** avec les crédits actuels (2 924,66 / 4 600) → **au-dessus du repère**, à afficher comme une lecture, jamais
comme un refus. Capacité au repère 35 % : **14 720,00 €** seulement (103,75 € de mensualité disponible), compte
tenu des crédits en cours — un chiffre inconfortable que l'écran doit énoncer calmement.

**Synthèse** — comptes 24 300,00 € · biens 492 500,00 € · **actif 516 800,00 €** ·
passif 234 129,21 € · **patrimoine net 282 670,79 €** · série 12 mois croissante (les valeurs de
biens sont **maintenues à plat**, plus ancienne estimation 12/01/2026).

## Panel 12 — Crédits

**Top bar.** « Crédits » / "Loans" + descriptor « Vos emprunts, leur coût et votre capacité »
(EN: "Your loans, their cost and your capacity"). Right: primary gradient « Nouveau crédit », user
pill.

**Content.** A summary row, then the loans.
- Summary row of three: **Charge mensuelle** (hero, the only iris-tinted card on the panel, same
  recipe as SavingsRateCard's tint) · **Capital restant dû** · **Taux d'endettement** — the ratio
  card names its income and its source (« sur un revenu déclaré de 4 600,00 € »), shows the 35 %
  HCSF reference, and carries the binds-no-lender line. Under the limit here: calm, not celebratory.
- Loan cards or rows (propose which; two loans of very different size is the case to design for):
  lender monogram, label, échéance totale, capital restant dû, a progress bar for the repaid share,
  next due date.
- **Detail state** (crédit immobilier): cost totals, TAEG labelled « indicatif », and the
  amortisation **DataTable** paged by year with a year switcher — columns Échéance · Intérêts ·
  Capital · Assurance · Capital restant dû, insurance in its own column, yearly totals in the
  header or foot. 300 rows never appear at once; design the year navigation.
- The amortisation curve is optional: if you draw one, it is the existing AreaLine or StackedBars
  family, principal against interest over time, and it must add something the table does not.

**States to show.** ① liste (fr) ② détail + tableau d'amortissement (fr) ③ modal nouveau crédit
(fr) ④ ratio sur revenu du grand livre, au-dessus du repère (fr) ⑤ ratio sans revenu connu (fr)
⑥ vide (fr) ⑦ liste (en).

State ⑤ is the one to get right: no ratio can be computed, so the card must say why and offer the
way out (declare an income) instead of drawing an empty gauge.

## Panel 13 — Impôts

**Top bar.** « Impôts » / "Taxes" + descriptor « Une estimation, pas une déclaration ». Right: year
selector pill (‹ 2025 › — same geometry as the dashboard's month pill), user pill.

**Content.** A SegmentedControl **Estimation | Paramètres fiscaux** heads the panel (the pattern
`08-categories-rules.md` uses). Two views:

*Estimation* — declaration form and result side by side or stacked (propose):
- The declaration: foyer (couple), personnes à charge, parent isolé, salaires, pensions,
  dividendes, intérêts, plus-values, option barème vs PFU, charges déductibles, crédits d'impôt.
  Property income is **absent** — it comes from the declared biens, and the form says so with a
  link to Synthèse rather than a field.
- **Prefill**: fields the ledger can suggest carry an accept affordance with their confidence and
  coverage (« Suggéré d'après vos imports · 12 mois · confiance élevée »). Design the accepted and
  the not-yet-accepted state of a field, and a low-confidence variant (« 4 mois importés »). Never
  a silently pre-filled field.
- **Result**: total estimé as the headline, taux moyen and taux marginal, then a component
  breakdown — IR, PFU (IR + PS), foncier (net + PS), IFI — each with its amount, accounting for
  the total exactly. The parts figure (2,5) is displayed as a result, not an input.
- **The limits card**: the estimation-first statement plus the named gaps from §16 (prélèvement à
  la source, PER, déficits fonciers, CSG déductible, abattements de durée, plus-values
  immobilières, micro-BIC/LMNP, taxe foncière, dettes IFI autres, revenus étrangers, demi-parts
  d'invalidité). This is content, not a footnote: design it to be read.
- « IFI : non redevable » is a **state to draw**, not an omission — say the base and the threshold.

*Paramètres fiscaux* — the barème and the parameter set **for the displayed year**, editable in
place, because the workings belong beside the number (§16):
- IR and IFI bracket DataTables (band floor, rate, implied ceiling), editable rows.
- Scalar parameters as labelled rows with their unit and a one-line explanation each.
- An overridden row is marked « ajusté » **and shows the official value beside it**.
- « Rétablir les valeurs officielles » for the whole year (confirmed via Modal) and per row
  (immediate).
- The way in from the estimate is the « ajusté » marker itself.

**States to show.** ① estimation (fr) ② estimation avec suggestions non acceptées (fr)
③ paramètres fiscaux (fr) ④ paramètres fiscaux, valeur ajustée + modal de rétablissement (fr)
⑤ année sans revenus déclarés — estimation à zéro, invitation (fr) ⑥ estimation (en).

## Panel 14 — Simulateur

**Top bar.** « Simulateur » / "Simulator" + descriptor « Ce qu'un nouveau crédit changerait ».
Right: secondary « Enregistrer le scénario », user pill.

**Content.** Form left, result right (or above/below — propose, but the result must move as the
inputs move, so keep them on screen together).
- Inputs: prix du bien, apport, montant emprunté (pre-derived, still editable), taux, durée
  (consider a Slider — it exists in the inventory since Phase 2), assurance, frais, and a Toggle
  « Inclure mes crédits actuels ».
- Result: échéance (payment + insurance, and say which is which), intérêts totaux, assurance
  totale, coût total, coût/prix, TAEG « indicatif ».
- Projection: yearly, in the existing chart family. Not 300 months.
- **HCSF reading**: ratio against 35 %, durée against 25 ans, and « capacité d'emprunt au repère ».
  With existing loans included this mock is at 63,6 % — design the over-reference state as a
  *reading in the warning tone with its reference point*, never a red refusal, and never a lecture.
  The capacity figure (14 720,00 €) must be stated calmly, with the reason it is small.
- Scenarios: a list of saved input sets, and a **comparison of up to three** side by side — same
  rows per column, a dash where a figure does not apply. The compare control disables past three
  and says why.

**States to show.** ① simulation en cours (fr) ② lecture au-dessus du repère, crédits actuels
inclus (fr) ③ comparaison de 3 scénarios (fr) ④ revenu inconnu — pas de ratio (fr) ⑤ vide, aucun
scénario (fr) ⑥ simulation (en).

## Panel 15 — Synthèse

**Top bar.** « Synthèse » / "Overview" + descriptor « Ce que vous possédez, ce que vous devez ».
Right: secondary « Nouveau bien », user pill.

**Content.**
- Headline: **patrimoine net** (neutral, Space Grotesk, tabular) with its month delta, then actif
  and passif. Assets split accounts / biens; liabilities from the loans.
- Composition in an existing recipe (Donut or HorizontalBars): comptes by type, biens by nature.
- **Series**: 12-month AreaLine, with its caveat *inline and legible* — property values are held at
  their declared value, oldest estimate 12/01/2026. Nothing in the drawing may imply the app knows
  a back-dated valuation. Months with no data are simply absent, not plotted at zero.
- **What is deliberately not counted**, stated in the panel: objectifs (an allocation labels money
  already in an account), abonnements and impôt estimé (a future charge is not a debt). One quiet
  line each — an unexplained absence reads as a missing feature.
- **Biens**: the property list lives here, with cards showing nature, valeur, « estimée le … », and
  the held share when ownership is under 100 % (72 500,00 € sur 145 000,00 €). Plus the create/edit
  modal: libellé, nature, valeur, date d'estimation, quote-part, prix et date d'acquisition, and the
  rent block — loyer, régime, charges — where charges appear **only** under « Réel ».
- Archiving a property warns that it leaves the IFI base too (the user is changing a tax figure
  from a net-worth screen).

**States to show.** ① synthèse (fr) ② liste des biens (fr) ③ modal nouveau bien, régime réel (fr)
④ aucun bien — synthèse sur les seuls comptes (fr) ⑤ vide (fr) ⑥ synthèse (en).

## Stage 2 — the panel description files

Write them **only after the frames are reviewed**, and write them as transcriptions. The existing
files (`10-subscriptions.md`, `11-goals.md`) are the model; match their shape and their register:

1. A one-line header: everything below is exactly what frames `NN-Panel — *` show; colours,
   amounts, order and positions are **normative — do not invent**; tokens per
   `00-shared-design-block.md`.
2. Sections, in this order, omitting none that applies: **Concept (binding)** where the panel rests
   on a rule that a later build could plausibly break · **Nav** (label fr/en, group position, icon
   description) · **Top bar (this panel)** · **Content** (every card, grid split, gap, padding,
   radius, border, exact copy, exact figures — tables where the frame has tables) · one section per
   additional state · **States to show** (the numbered list) · **Notes** (interactions the static
   frames cannot show, and anything you decided against with the reason).
3. Every colour as a token or a hex from the shared block; every size in px; every string in fr
   with its en counterpart where the frame set carries one.
4. Name components by their shared-block `§Components` names. If you introduced an element, specify
   it fully enough to be built without the canvas open.
5. Append a **Phase 3 additions** paragraph to `00-shared-design-block.md` covering: the Patrimoine
   group and its four icons, any new component you introduced, and any token the Phase 3 frames add
   (a new tint, a new pill, a table density). Do not restate what Phase 1 or 2 already established.
6. **Amendments survive regeneration** (`01-tool-wrappers.md`): the shipped Flutter code is the
   source of truth for any panel already built. Never write a token into these files that
   contradicts `frontend/lib/core/theme/tokens.dart`, and never silently undo a recorded
   amendment — the Geist swap, the `#0A0F15` field tone, the SavingsRateCard tint, the absent spin
   token, the flexible TransactionRow label.
7. Say plainly, in the Impôts file's Notes, that its figures are **visual** mock data and not a
   calculation oracle: the verified engine is the backend's (`PROJECT.md` §16).

## Ask, do not guess

Stop and ask rather than inventing, if: the sidebar stack no longer breathes with a fourth group;
a panel needs a component the inventory cannot carry; the mock figures above contradict each other
somewhere; French copy will not fit a box at 1440 px without a token change; or a state listed above
turns out to be two states that need drawing separately. An invented answer becomes normative the
moment the description file is written, which is the expensive kind of wrong.
