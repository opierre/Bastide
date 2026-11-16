# 06 — Imports

Mockup: `#panel=imports`. Ticket #209. Read `00-design-system.md` first.

## Title bar
Title « Imports ». No control.

## Layout
Standard padding. Two blocks, 24 px apart:

1. **New import:** the drop target, then (10 px below) one line per selected file.
2. **Historique:** heading, then the history table, which takes the remaining height and
   scrolls inside the content region.

## Content

### 1. New import
- **Drop target** (`00` §7): `file-up` icon · « Déposez un relevé OFX ou QFX » (13 `text`)
  over « Le relevé indique son compte. Rien n’est importé avant votre confirmation. » (12
  `textSecondary`) · spacer · secondary « Parcourir ». Clicking anywhere opens the file dialog.
- **Selected-file line** (a Banner), one per statement found in the file:
  `file-text` · file name (Geist Mono) · size `textTertiary` · vertical hairline · the
  detection result · spacer · ghost « Retirer » (`x`) · primary « Importer ».

| Detection | Shown in the line |
|---|---|
| Account recognised | `check` `positive` « Compte reconnu » + monogram + account name. « Importer » enabled. |
| Several accounts match | `triangle-alert` `warning` « Plusieurs comptes correspondent » + a 28 px select limited to the candidates. « Importer » disabled until one is picked. |
| File names no account | `triangle-alert` `warning` « Aucun compte indiqué » + a select listing every account. |
| Account does not exist | `triangle-alert` `warning` « Compte inconnu : {label} » + secondary « Créer ce compte » (opens the account form prefilled). |
| Two statements to one account | `circle-x` `negative` « Deux relevés vont vers le même compte. Choisissez une destination différente. » |
| Unreadable file | `circle-x` `negative` « Fichier illisible. Rien n’a été modifié. » Only « Retirer ». |

- While importing: the primary button shows the spinner and « Import… »; the line cannot be
  removed.
- After import the line disappears and the new batch appears as the first history row,
  highlighted with `accentSoft` for 4 s. A toast confirms: « 42 nouvelles opérations · 3
  doublons ignorés ».

### 2. Historique
| Column | Content |
|---|---|
| Fichier | File name in Geist Mono. A note sits on a second line, 12 px: `warning` for duplicates (« 6 opérations déjà présentes ont été ignorées. »), `negative` for a failure. The row is 48 px when it has a note. |
| Compte | Monogram + account name; « — » for a failed import |
| Importé le | date, `textSecondary` |
| Période couverte | « 1 – 30 avr. 2026 », `textSecondary` |
| Nouvelles | right-aligned |
| Doublons | right-aligned, `textSecondary` |
| Résultat | right-aligned status text: « Réussi » neutral with `check`; « Partiel » `warning`; « Échec » `negative`. A balance mismatch adds « Écart de solde » in `warning`. |

Newest first. A row opens Transactions filtered on that import.

## States
| State | What shows |
|---|---|
| Idle with history | Drop target + table. |
| File selected | One or more selected-file lines. |
| Drag-over | Drop target in its drag-over look. |
| Empty history | Under the heading, an empty state inside the table area: « Aucun import » · « Déposez un relevé ci-dessus : vos opérations apparaîtront ici. » No button (the drop target is above). |
| Loading | Table silhouette. |

## Behaviour (kept)
- OFX and QFX only, French SGML and Latin-1 dialects included. CSV is not accepted; a CSV
  dropped here is reported as unreadable with « Format non pris en charge. »
- A statement routes to the account its own header names. The panel never guesses: an
  unresolved file leaves « Importer » disabled.
- One file can hold several statements; each gets its own line.
- Duplicates are skipped by FITID or dedup hash; re-importing a file is safe.
- The history is never editable; a failed import changes nothing.

## Copy
Delete `navImportsSubtitle`. `importDropZoneHint`, `importFailedNote`,
`importUnreadableAccount`, `importDetectedAccountAmbiguous`, `importHistoryEmptyTitle` per `00`
§14. Status words stay « Réussi », « Partiel », « Échec ».

## Removed from v1
Glyph-plate drop zone, the « Dernier import » result card with count plates, green and amber
tinted detection banners, OFX/QFX format badge pills, status pills, card frames.
