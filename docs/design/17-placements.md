# 17 — Placements (new panel)

Mockup: `#panel=investments`. Tickets #217 (data model and API) and #218 (panel). Read
`00-design-system.md` first.

## Concept (binding)
Bastide follows an investment envelope (PEA, assurance vie, PEE, PER, compte-titres) **from
the values the user declares**. It connects to no broker and downloads no price.

- The user creates a placement, records payments in and withdrawals, and copies its value from
  a statement whenever they want.
- Bastide computes, and never stores: net payments (paid in − withdrawn), unrealised gain
  (last declared value − net payments), gain as a share of net payments, age since opening.
- Every figure is neutral, the gain included (it is not income until it is withdrawn). A gain
  carries its sign.
- Money is signed integer minor units; one currency per user.
- A placement is not an account: it has no import and no transactions of its own. A movement
  may be linked to an imported transaction (the transfer that funded it) for the user's
  reference; the link changes no total.
- Fiscal milestones are indicative readings and say so.

**Open decisions, to settle before #217 starts** (ask the user; do not guess):
1. Per-fund holdings (supports, unités de compte): not in this version. Value is tracked per
   envelope only.
2. The envelope catalogue and its milestones below were written from general knowledge of
   French rules and must be checked by the user before they ship.

| Envelope | Payment ceiling shown | Age milestone shown |
|---|---|---|
| PEA | 150 000 € | 5 years |
| PEA-PME | 225 000 € (combined with a PEA) | 5 years |
| Assurance vie | none | 8 years |
| PER | none | none |
| PEE | none | 5 years |
| Compte-titres | none | none |
| Autre | none | none |

## Navigation
New sidebar item « Placements » (`chart-line`) in « Patrimoine », after Crédits. Route
`/investments`.

## Title bar
Title « Placements ». Right: primary « Nouveau placement » (`plus`).

## Layout
Flush panel, two panes: **list** (flexible, padding 24 32) · **inspector** (440 px).

## Content

### List pane, top to bottom, 20 px apart
1. **Summary line:** lead « Valeur déclarée » 40 px with « {n} placements · dernière valeur
   saisie le {date} » · « Versements nets » 20 px with « versé − retiré » · « Plus-value
   latente » 20 px, neutral with its sign, with a neutral trend line « +16,1 % des
   versements ».
2. **Table**, rows 48 px:

| Column | Content |
|---|---|
| Placement | Monogram (institution) + name 13/500 over « {envelope} · {institution} · ouvert en {mois année} » 11 `textTertiary` |
| Versements nets | right |
| Valeur déclarée | right, 13/500 |
| Plus-value | right: signed amount, then the percent in `textTertiary` |
| Valeur au | right, date `textSecondary`; when older than the stale limit, a `warning` status text `clock-alert` + the date |

   The selected row takes `accentSoft` and fills the inspector; the first is selected on
   arrival. Closed placements are listed last, dimmed.
3. **Stale-value Banner**, one per stale placement (at most three, then « et {n} autres »):
   `clock-alert` `warning` icon · « La valeur du {name} date de plus de quatre mois. » ·
   secondary « Mettre à jour la valeur ».
4. At the bottom of the pane, a Note: `lock` + « Bastide ne se connecte à aucun courtier et ne
   télécharge aucun cours. La valeur est celle que vous recopiez depuis votre relevé. La
   plus-value est calculée, jamais enregistrée. »

### Inspector pane, 16 px apart
1. Header row: large monogram · name 16/600 over « {institution} · ouvert le {date} » 12
   `textTertiary` · spacer · secondary icon button `ellipsis` (Modifier, Clôturer, Supprimer).
2. A row: value at 28 px · « au {date} » `textSecondary` · spacer · gain signed + percent
   `textTertiary`.
3. Buttons: primary « Saisir la valeur » (`pencil`) · secondary « Versement ou retrait »
   (`plus`).
4. Legend: « Valeur déclarée » (`accent`) · « Versements nets » (`textTertiary`).
5. Chart, 170 px: the declared values as a line/area with one dot per declaration; net
   payments as the second series (step line). Between two declarations the value is held flat
   and that stretch of area is hatched (`00` §9). Hover card: date, value, net payments.
6. Hairline. Repères, each with its label left and its value right on one line:
   - « Plafond de versement »: net paid in / ceiling, no mark. Only for an envelope with a
     ceiling.
   - « Ancienneté »: « 3 ans 2 mois »; scale 0–8 years; mark at the envelope's milestone
     labelled « repère 5 ans · mars 2028 ». Under it, 12 `textTertiary`, for a PEA: « Avant 5
     ans, un retrait clôt en principe le plan. Lecture indicative, qui ne vaut pas conseil
     fiscal. » For an assurance vie: « Après 8 ans, la fiscalité des retraits s’allège.
     Lecture indicative, qui ne vaut pas conseil fiscal. » Only for an envelope with a
     milestone; past it the repère is `done`.
7. Hairline. « Mouvements » heading; right 12 `textTertiary` « {n} rapprochés avec vos
   transactions » when any. Table without header, newest first, payments, withdrawals and
   declared values in one list: date `textSecondary` · « Versement », « Retrait » or « Valeur
   saisie » (+ the note when there is one) · amount right: a payment `+` and a withdrawal `−`
   in `text`; a declared value unsigned in `textSecondary`. A row opens its edit modal.

### Modals (all 440 px)
- **Nouveau placement / Modifier:** Nom · Enveloppe (select from the catalogue) ·
  Établissement · Date d’ouverture · Valeur actuelle (optional) · Versements déjà effectués
  (optional; creates one opening movement at the opening date). Footer « Annuler » ·
  « Enregistrer ».
- **Saisir la valeur:** lead = the placement's name. Valeur · Date (default today, not in the
  future) · Note. Helper: « Recopiez la valeur totale indiquée sur votre relevé. »
- **Versement ou retrait:** Montant (helper « Un montant négatif est un retrait. ») · Date ·
  Note · Transaction liée (optional select of recent transfers of the same amount).
- **Clôturer:** asks the closing date and the final amount received; the placement leaves the
  net worth from that date and stays listed, dimmed.

## States
| State | What shows |
|---|---|
| Populated | As above. |
| Stale value | `warning` date in the row and the Banner. Stale limit: 4 months. |
| Placement with no declared value | Value « — »; gain « — »; the chart shows net payments only and the note « Saisissez une valeur pour voir la plus-value. » |
| Loss | Gain negative with `−`, still neutral. |
| Ceiling reached | Repère full, `over`; caption « Plafond de versement atteint. » |
| Empty | Single pane, empty state: « Aucun placement » · « Suivez un PEA, une assurance vie ou un autre placement à partir des valeurs de vos relevés. » · primary « Nouveau placement ». |
| Loading | Silhouettes of both panes. |
| English | « Investments », « Declared value », « Net payments », « Unrealised gain ». |

## Behaviour
- Net worth (`15-synthese.md`) counts each placement for its last declared value on or before
  the month's end; before the first declaration it counts net payments.
- Backup, restore and reset include placements, movements and valuations.
- Deleting a placement removes its history after a confirmation that says so; closing keeps
  it.
- Nothing here reads or writes an account balance.

## Copy
All strings are new, fr and en. French terms: « Placements », « Valeur déclarée »,
« Versements nets », « Plus-value latente », « Saisir la valeur », « Versement ou retrait »,
« Mouvements », « Valeur saisie », « Plafond de versement », « Ancienneté », « Clôturer ».
