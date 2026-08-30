# 07 — Transactions

## Top bar (this panel)
Title « Transactions » + descriptor « Toutes vos opérations, en un seul fil ». Right: wide search (300 px, « Rechercher une description ou un marchand… »), user pill.

## Content layout
Filter bar (36 px pills, raised surface): Tous les comptes · 01/05/2026 – 31/05/2026 (opens the 420 px « Période » Modal — two DateFields, Du/Au, on the app's own calendar picker; both left empty lifts the filter) · Toutes les catégories · right-aligned « À vérifier » label + Toggle (amber count badge 12 when on). List Card: 52 px TransactionRows (30 px monogram · 290 px two-line merchant + account block · CategoryChip with category icon · date · 120 px signed tabular amount), #1A212C separators only, hover #151B26; footer pager « 1–12 sur 128 » + round ‹ › buttons. Twelve May-2026 rows from Carrefour to Salaire — Novatech SARL (+2 850,00 € green). Category picker: clicking a chip opens a 250 px overlay popover anchored under it — search field « Changer de catégorie… » + category rows (swatch + name) with iris check on the current one. Review queue: iris-tinted progress Card « 12 transactions à vérifier » / « 4 catégorisées aujourd'hui — vous y êtes presque, continuez ! » + 4/16 and a 25 % iris progress bar; then 64 px rows: "?" monogram, raw bank label in monospace (PRLV SEPA CAISSE LOC EPARGNE…), dashed « Non catégorisé » chip, suggested CategoryChips (with their category icons), iris « Toujours catégoriser ainsi » rule affordance, signed amount.

## States to show
① populated (fr). ② populated (en) — same geometry, May 14 2026 / −€86.42 formatting. ③ category picker open (fr) — on the Carrefour row. ④ review queue (fr) — toggle on. ⑤ empty (fr) — EmptyState « Aucune transaction pour l'instant » + CTA « Aller aux imports », filter bar hidden.

## Phase 2 amendment — AI proposals in the review queue
Normative reference: frames `07-Transactions — *` in `FinStride Phase 2 Mockups.dc.html`. The review queue gains local-AI proposals; everything else in this file stands.

**Row anatomy with proposal** (66 px min): "?" monogram (32 px, #1E2634/#97A3B6) · 280 px block: raw bank label monospace 12.5 + date 11.5 `#5A6579` · **ProposedCategoryChip** (dashed, category hue — see 00 §Phase 2) · **ConfidenceGauge** + « Confiance NN % » · spacer · gradient button « Confirmer » (30 px, check icon) · secondary « Corriger » (30 px, border #232B38) · 110 px signed amount. Row without proposal: dashed neutral « Non catégorisé » chip + italic « — aucune proposition » 11.5 `#5A6579`, iris link « Choisir une catégorie » on the right. Exact demo rows: CB NOVATECH SAS 12/05 · 12/05/2026 · −49,90 € · proposé « Achats › Électronique » 71 % — PRLV SEPA ASSUR MAIF · 11/05/2026 · −187,44 € · « Logement › Assurance habitation » 78 % — VIR RECU M. DUBOIS · 09/05/2026 · +420,00 € green · no proposal — CB SNCF CONNECT · 07/05/2026 · −86,40 € · « Transport › Transports en commun » 74 %.

**Header Card** (iris-tint, same recipe as review Card): « 12 transactions à vérifier » + « L'IA locale propose une catégorie pour 3 d'entre elles — confirmez ou corrigez, rien n'est classé sans vous. » + 4/16 + 25 % progress bar. Amber count badge in the filter bar follows the queue size.

**Running state** (replaces the header Card while classifying): iris-tint banner with 18 px spinner (2.5 px ring, border-top iris, spin .9 s) · « Catégorisation en cours — 84 sur 213 transactions » · sub « 61 classées · 23 à vérifier · le panneau reste utilisable » · secondary « Annuler » · 6 px progress bar at 39 %, fill linear-gradient(90deg,#6C6AF0,#8B8CF9). Non-blocking: the list stays interactive beneath.

**Finished-with-failures banner** (amber, dismissible ×): « Catégorisation terminée — 12 transactions n'ont pas pu être analysées. » + underlined « Voir ».

**Rule modal « Toujours catégoriser ainsi »** (520 px, overlay surface): sub « Une règle classe ces transactions sans IA, à chaque import — pré-remplie depuis “PRLV SEPA ASSUR MAIF”. » Fields: Champ = Description · Condition = contient · Motif (focused, monospace) = ASSUR MAIF · Catégorie cible = Logement › Assurance habitation (cyan swatch). Checked gradient checkbox « Appliquer aux transactions existantes » + blue info banner « Correspond à 7 transactions existantes. » Footer: Annuler · Créer la règle. On create: success Toast bottom-right « Règle créée · 7 transactions recatégorisées » (green check plate).

**AI-not-configured state**: queue rows render Phase 1 style (no chips proposal, no gauges, no buttons) + calm blue invitation banner at the Card foot: « Activez l'IA locale pour classer automatiquement les transactions que vos règles n'ont pas reconnues. » + iris link « Paramètres ». Never nags anywhere else.

**Phase 2 states**: ⑥ file avec propositions IA + toast (fr) ⑦ catégorisation en cours (fr) ⑧ modal règle + bannière terminée (fr) ⑨ IA non configurée (fr).

**Rules**: proposals never auto-apply — below the confidence threshold (see 09) a transaction enters this queue; at/above it, it is classified and does NOT appear here. « Confirmer » assigns the proposed category and clears the review flag; « Corriger » opens the standard category picker. Deterministic rules (08) always win over AI proposals.

## Notes
Choosing a category in the picker or a suggestion chip clears the review flag; « Toujours catégoriser ainsi » creates a rule (see 08). Review copy is framed as progress, never as a backlog of failures.