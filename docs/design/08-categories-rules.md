# 08 — Categories & Rules

## Top bar (this panel)
Title « Catégories » + descriptor « Organisez vos dépenses, automatisez avec des règles ». Right: primary button (contextual label « Nouvelle catégorie » / « Nouvelle règle »), user pill.

## Content layout
A 300 px SegmentedControl (Catégories | Règles) heads the content. Categories view: one Card, 41 px rows — parent rows: 12 px swatch (radius 4) + name 13.5/700 + Système badge (neutral) or Personnalisée badge (iris tint) + 220 px spend-share bar in the category's own hue + % + month amount + trailing enable Toggle (34×20 switch with explicit knob, iris when on — parent rows only) then lock glyph (system, non-deletable) or ⋯ (custom); subcategory rows indent 30 px at 12.5/400 with amount only (Logement → Loyer/Prêt, Charges; Alimentation → Courses, Restaurants; Transport → Carburant, Transports en commun; Revenus → Salaire, Remboursements; custom « Épargne projet »). Rules view: right of the control, a note « Évaluées dans l'ordre de priorité — une règle ne remplace jamais une catégorie choisie manuellement. » + secondary « Exécuter les règles »; Card of 52 px drag-reorderable rows: 6-dot handle · priority plate · field · condition badge (contient/égal à/regex/plage) · monospace pattern · → target CategoryChip · enabled Toggle (same 34×20 explicit-knob switch). Six rules, AMAZON rule disabled at 50 % opacity (toggle off).

## States to show
① categories (fr). ② rules + toast (fr) — Toast bottom-right « 48 transactions recatégorisées » / « Vos catégories choisies manuellement n'ont pas été modifiées. » ③ rule editor + match preview (fr) — 520 px Modal: Champ/Condition/Priorité row, Motif field focused (iris ring, CARREFOUR), target chip « Alimentation › Courses », info InlineBanner « Correspond à 7 transactions existantes — dont "CB CARREFOUR PARIS 15" du 14/05/2026. », active toggle, Annuler/Enregistrer. ④ rules empty (fr) — EmptyState explaining what a rule does, CTA « Nouvelle règle ».

## Notes
System/custom distinction is triple-encoded: badge text, badge tint, lock vs ⋯. Create/edit category modal (Nom, Kind, Parent, icon, color) follows the 05 modal pattern and was not drawn as a separate frame.