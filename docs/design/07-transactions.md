# 07 — Transactions

## Top bar (this panel)
Title « Transactions » + descriptor « Toutes vos opérations, en un seul fil ». Right: wide search (300 px, « Rechercher une description ou un marchand… »), user pill.

## Content layout
Filter bar (36 px pills, raised surface): Tous les comptes · 01/05/2026 – 31/05/2026 · Toutes les catégories · right-aligned « À vérifier » label + Toggle (amber count badge 12 when on). List Card: 52 px TransactionRows (30 px monogram · 290 px two-line merchant + account block · CategoryChip with category icon · date · 120 px signed tabular amount), #1A212C separators only, hover #151B26; footer pager « 1–12 sur 128 » + round ‹ › buttons. Twelve May-2026 rows from Carrefour to Salaire — Novatech SARL (+2 850,00 € green). Category picker: clicking a chip opens a 250 px overlay popover anchored under it — search field « Changer de catégorie… » + category rows (swatch + name) with iris check on the current one. Review queue: iris-tinted progress Card « 12 transactions à vérifier » / « 4 catégorisées aujourd'hui — vous y êtes presque, continuez ! » + 4/16 and a 25 % iris progress bar; then 64 px rows: "?" monogram, raw bank label in monospace (PRLV SEPA CAISSE LOC EPARGNE…), dashed « Non catégorisé » chip, suggested CategoryChips (with their category icons), iris « Toujours catégoriser ainsi » rule affordance, signed amount.

## States to show
① populated (fr). ② populated (en) — same geometry, May 14 2026 / −€86.42 formatting. ③ category picker open (fr) — on the Carrefour row. ④ review queue (fr) — toggle on. ⑤ empty (fr) — EmptyState « Aucune transaction pour l'instant » + CTA « Aller aux imports », filter bar hidden.

## Notes
Choosing a category in the picker or a suggestion chip clears the review flag; « Toujours catégoriser ainsi » creates a rule (see 08). Review copy is framed as progress, never as a backlog of failures.