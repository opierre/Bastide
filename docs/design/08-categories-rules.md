# 08 — Catégories et règles

Mockup: `#panel=categories`. Ticket #210. Read `00-design-system.md` first.

## Title bar
Title « Catégories et règles ». Right: secondary « Exécuter les règles » (`play`), primary
« Nouvelle règle » (`plus`).

## Layout
Flush panel, two panes: **category tree** (340 px, right hairline, padding 16 12) · **rules**
(flexible). The tree selects what the rules pane shows. There is no segmented control.

## Content

### Category tree
- Header row, padding 0 8 8: « Catégories » 13/600 · spacer · ghost icon button `plus`
  (new category).
- First item: « Toutes les règles » with the total count; selected by default.
- One item per top-level category, in the user's order (30 px, radius 6, the nav-item recipe):
  `chevron-right` / `chevron-down` 14 px `textTertiary` · 8 px dot in the category hue ·
  category icon 14 px · name · on the right, 11 `textTertiary`: « 2 règles », or « aucune
  règle » in `warning`.
- An open category lists its subcategories indented 52 px, each with its own icon 14 px in
  its main category's hue and no dot, then a `textTertiary` item `plus` + « Sous-catégorie ».
- Selected item: `hover` ground, `text`.
- A system category shows a `lock` 14 px `textTertiary` on hover in place of the menu; a
  custom one shows `ellipsis` (menu: « Modifier », « Supprimer »). A custom subcategory opens
  its form on click; a system subcategory is inert.
- Foot of the pane, a Note: `lock` + « Les catégories fournies avec Bastide ne peuvent pas
  être supprimées. »

### Rules pane
- Header row, padding 16 32 0: « Règles » 13/600 · when a category is selected, a 28 px
  select-look holding its category label and an `x` that returns to « Toutes les règles » ·
  spacer · 12 `textTertiary`: « Appliquées dans cet ordre. Une catégorie choisie à la main
  n’est jamais remplacée. » · the pack actions (import a file, import the built-in pack,
  export), 8 px apart: secondary icon buttons, 28 px high with the button's 0 10 padding
  around the 14 px icon (36 × 28), each named by a tooltip.
- Table, edge to edge:

| Column | Content |
|---|---|
| Ordre | `grip-vertical` 14 px `textTertiary` + the rule's position |
| Champ | « Description », « Montant »… `textSecondary` |
| Condition | « contient », « égal à », « regex », « plage », `textSecondary` (plain text, no badge) |
| Motif | Geist Mono |
| Catégorie | Category label with its subcategory |
| Correspondances | right, count of operations the rule classed, `textSecondary` |
| Active | right, toggle |

  A disabled rule's row is dimmed. A row opens the rule editor. A rule that carries a user
  logo shows it as the 22 px monogram before the pattern.

### Rule editor (modal, 520 px)
Title « Nouvelle règle » / « Modifier la règle ». One row: Champ · Condition · Priorité. Then
Motif (Geist Mono) · Catégorie cible (select) · a Note « Correspond à 7 opérations existantes,
dont « CB CARREFOUR PARIS 15 » du 14 mai 2026. » · Logo (22 px preview, secondary « Choisir une
image » (« Remplacer… » once a logo is set) and « Depuis une adresse… », ghost « Retirer »; on a new rule only the helper « Enregistrez la règle pour lui
ajouter un logo. ») · toggle « Active ». Footer: ghost « Supprimer » on the left (edit only,
confirmed) · « Annuler » · « Enregistrer ».

### Category form (modal, 480 px)
Nom · Type (Dépense, Revenu, Transfert) · Parent (select, optional) · Icône (a grid of the
curated Lucide set, 32 px cells, selected cell `hover` + `accent` outline; each cell is named in
French, « Tirelire » for `piggy-bank`) · Couleur (the eleven category slots as 20 px squares, named
Bleu, Orange, Vert, Ambre, Rose, Violet, Prune, Cyan, Olive, Brun, Gris; the selected one takes the `accent` outline and a
12 px `check` in `bg` in dark and `text` in light, at least 3:1 on every slot). With a parent set, Type, Icône and Couleur are hidden and the
modal's lead repeats the parent's category label.

### Rule packs
The import and export sheets keep their content and become modals (560 px) built from the
standard table, checkbox and note components. The built-in pack button hides once that pack is
imported.

The export modal opens on its privacy warning as a Banner (`00` §7) with a `triangle-alert`
icon in `warning`, not a Note: « Relisez avant d’enregistrer. Un motif peut contenir des
informations personnelles, comme le nom de votre propriétaire : « VIR LOYER DUPONT ». » It has
no action and no close. The JSON preview below it is unchanged.

### Other modals (`00` §7)
- **Delete a rule** (480 px), destructive confirmation: « Supprimer la règle « {motif} » ? »,
  lead « Les opérations qu’elle a déjà classées gardent leur catégorie. »
- **Delete a category** (480 px), destructive confirmation: « Supprimer la catégorie
  « {nom} » ? », lead « Ses sous-catégories seront supprimées aussi. Les transactions
  concernées redeviendront non catégorisées. »
- **Logo crop** (420 px), square crop 320 × 320; footer « Annuler » · « Utiliser ce logo ».
- **Logo from an address** (420 px): lead « Collez l’adresse d’une image. Bastide la
  télécharge depuis cet ordinateur, puis vous la recadrez. »; Adresse de l’image (Geist Mono);
  footer « Annuler » · « Télécharger ».
- **Logo zoom** (240 px), the zoom variant.
- **Pack refused** and **logos not added** (480 px), acknowledgements with a single « Fermer ».
  A pack refused for a regex rule says: « Rien n’a été importé. Ce pack contient une règle
  « regex », que Bastide n’accepte pas d’un fichier partagé : écrite par quelqu’un d’autre,
  elle pourrait ralentir fortement l’application. Les conditions « contient », « égal à » et
  « plage » sont acceptées. »
- **Logos downloading** (the import modal, 560 px): progress « Téléchargement des logos… {n} /
  {total} » with a meter and the note that the rules are already imported. Secondary
  « Arrêter les téléchargements » closes it; the logos not yet downloaded join the « logos not
  added » result.

## States
| State | What shows |
|---|---|
| All rules | Tree with « Toutes les règles » selected; rules can be dragged to reorder. |
| Filtered on a category | That category's rules (its subcategories' included); drag-reorder off; the grip is hidden. |
| No rule at all | In the rules pane, an empty state: « Aucune règle » · « Une règle reconnaît un libellé, « CARREFOUR » par exemple, et attribue sa catégorie à chaque opération correspondante, aujourd’hui et aux prochains imports. » · primary « Nouvelle règle ». |
| No rule for the selected category | Note: « Aucune règle pour cette catégorie. » + link « Nouvelle règle ». |
| Rules run | Toast: « 48 opérations recatégorisées » / second line « Vos catégories choisies à la main n’ont pas été modifiées. » |
| Loading | Silhouettes of both panes. |

## Behaviour (kept)
- No amount or spending share appears here: this is taxonomy management. Spending lives on the
  Dashboard.
- Categories are always active; there is no enable toggle for a category.
- Rules are evaluated in priority order, first match wins; a rule never replaces a category
  chosen by hand.
- Regex rules and rules that target a custom category cannot go into a rule pack.
- A logo on a rule is the user's own file; it stays on their machine and is never looked up.
- System and custom categories differ by the lock versus the menu; no badge.

## Copy
Delete `navCategoriesSubtitle`. `rulesPriorityNote`, `rulesEmptyTitle`, `categoriesEmptyTitle`
per `00` §14. Remove the « Système » / « Personnalisée » badge strings. New: « Toutes les
règles », « Correspondances », « aucune règle », « Sous-catégorie ».

## Removed from v1
The Catégories | Règles segmented control, the 4-column CategoryCard grid, tinted icon tiles,
SubcategoryChips, « Système » / « Personnalisée » badges, kind label under the name, priority
plate, condition badge, card frame around the rules, the arrow before the target category.
