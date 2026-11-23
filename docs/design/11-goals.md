# 11 — Objectifs

Mockup: `#panel=goals`. Ticket #212. Read `00-design-system.md` first.

## Concept (binding)
An objective is a virtual envelope: an on-paper allocation that never modifies an account and
never creates a transaction. It is linked to no account, and no account is shown on it.

## Title bar
Title « Objectifs ». Right: primary « Nouvel objectif » (`plus`).

## Layout
Flush panel, two panes: **list** (flexible, padding 24 32) · **inspector** (440 px, `00` §7).

## Content

### List pane, top to bottom, 16 px apart
1. **Summary line:** lead « Réservé sur {n} objectifs » 40 px, neutral · « Épargne
   disponible » 20 px (the total of savings accounts).
2. **Over-allocation Banner** (only when reserved > available savings): `info` icon · « Vous
   avez réservé {delta} de plus que le total de vos comptes d’épargne. » · ghost close.
   Neutral, not a warning.
3. **Table**, rows 48 px:

| Column | Content |
|---|---|
| Objectif | A 36 × 24 px thumbnail of the banner image (radius 4) when the goal has one, then the name 13/500 |
| Échéance | « Sans échéance », « Juin 2028 » `textSecondary`; when reached, `check` `positive` « Atteint en avril 2026 » |
| Avancement | Repère, 30 % of the width; `done` when reached |
| Réservé | right: saved, then « / target » in `textTertiary` |
| (percent) | right, 13 `text` |

   The selected row takes `accentSoft` and fills the inspector. The first goal is selected on
   arrival.
4. Link row: `archive` 14 px + « {n} objectifs archivés » 12 `textSecondary`. Clicking lists
   the archived goals under the table, dimmed, with a `muted` repère.
5. At the bottom of the pane, a Note: `lock` + « Un objectif réserve une somme sur le papier.
   Vos comptes ne sont pas modifiés. Les images restent sur cet ordinateur. »

### Inspector pane
1. **Banner**, edge to edge at the top of the pane (it ignores the pane's padding), 190 px
   tall:
   - **With an image:** the picture, cover-cropped. A bottom fade from transparent to
     `rgba(12,14,24,.82)` covers the lower 100 px. Over the fade, bottom-left at 24 px: the
     goal name 16/600 in `#FFFFFF` over the deadline line 12 `#D9DCE6`; bottom-right: the
     percent 16/600 `#FFFFFF`. Top-right at 12 px: secondary « Changer » (`image`). These two
     whites are fixed in both themes because they sit on the image's fade.
   - **Without an image:** 120 px tall, tomettes on `rail` with a bottom hairline; the name
     16/600 `text` and deadline 12 `textSecondary` bottom-left; top-right secondary « Ajouter
     une image » (`image-plus`).
2. Padded content (18 24 24), 16 px apart:
   - A row: saved at 28 px · « sur {target} » `textSecondary` · spacer · three square
     secondary icon-only tool buttons, 6 px apart: « Modifier » (`pencil`), « Archiver »
     (`archive`) and « Supprimer » (`trash-2`). Each label is the button's tooltip and
     accessible name.
   - Repère (`done` when reached).
   - Without an image, or when not reached: one 12 `textTertiary` line « {deadline} · reste
     {remaining} ».
   - Hairline.
   - « Allocations » heading; right: secondary « Allouer » (`plus`).
   - Table without header: date `textSecondary` · note · signed amount (coloured) · a
     trailing ghost icon button « Supprimer l’allocation » (`trash-2`), shown on row hover or
     keyboard focus. Newest first; scrolls inside the pane. An archived goal has no delete
     action.

### Banner image
- Picked with the same file picker and square-free crop modal as the avatar, cropped to 44:19.
- PNG, JPEG or WebP, same size limit and error messages as the avatar.
- Stored locally with the goal, included in the `.bastide` backup, deleted with the goal or
  with « Retirer l’image » (in the « Changer » menu).
- While it loads or if it fails, the no-image banner shows. Never a broken image.

### Modals
- **New / edit goal** (440 px): Nom · Montant cible · Échéance (facultative, a month) ·
  Image (facultative, same picker). Footer « Annuler » · « Enregistrer ». No « Supprimer »:
  deleting is the inspector's « Supprimer » tool button.
- **Delete goal** (440 px): title « Supprimer l’objectif « {name} » ? », lead « Ses
  allocations et son image seront supprimées. Pour garder son historique, archivez-le
  plutôt. Vos comptes ne sont pas modifiés. » Footer « Annuler » · destructive
  « Supprimer ». The inspector falls back to the first goal.
- **Allocation** (440 px): title « Nouvelle allocation », lead = the goal's name. Montant
  (helper « Un montant négatif retire de l’objectif. ») · Date · Note (facultative). Footer
  « Annuler » · « Ajouter ». One signed amount field; no deposit/withdraw modes.
- **Delete allocation** (440 px): title « Supprimer l’allocation du {date} ? », lead « Le
  montant mis de côté pour « {goal} » baisse de {amount}. Vos comptes ne sont pas modifiés. » (« remonte de » for a
  negative line). Footer « Annuler » · destructive « Supprimer ». After the delete, the saved
  figure, the repère, the percent and « Atteint en … » are reloaded from the backend.

## States
| State | What shows |
|---|---|
| Populated, goal with image | As above. |
| Populated, goal without image | The tomettes banner. |
| Goal reached | `done` repère, « Atteint en {mois} » in the list and on the banner. Reached goals are not archived automatically. |
| Over-allocated | The Banner in the list pane. |
| Archived list open | Archived rows under the table; selecting one shows it in the inspector with « Désarchiver » (`archive-restore`) in place of « Archiver », no « Modifier » and no « Allouer »; « Supprimer » stays. |
| Empty | Single pane, empty state: « Aucun objectif » · « Un objectif réserve une somme sur le papier. Vos comptes ne sont pas modifiés. » · primary « Nouvel objectif ». |
| Loading | Silhouettes of both panes. |
| English | « Reserved across 4 goals », « Reached in April 2026 ». |

## Behaviour (kept)
- Progress above 100 % clamps the repère and prints the real percent.
- Allocation amounts follow the money rule; a withdrawal is a negative line in the same list.
- Archiving removes the goal from the active list and from the Dashboard, keeps its history,
  and can be undone.
- Objectives are not counted in the net worth.

## Copy
Delete `navGoalsSubtitle`, `goalHistorySubtitle`. `goalsEmptyTitle`, `goalsEmptyBody` per `00`
§14. New: « Réservé sur {n} objectifs », « Épargne disponible », « Allouer », « Changer »,
« Ajouter une image », « Retirer l’image », « reste {remaining} ».

## Removed from v1
GoalCard grid, the separate detail view with its 96 px ring and back link (the inspector
replaces it), the tinted reached card, date pills, the blue tinted banner, gradient bars.
