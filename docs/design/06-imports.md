# 06 — Imports

## Top bar (this panel)
Title « Imports » + descriptor « Relevés OFX, QFX et CSV — traités sur cet ordinateur ». Right: user pill only — account selection lives in the panel.

## Content layout
Region A « Nouvel import » (Card, left, flex 1.35): Compte de destination select (340 px, with monogram) + DropZone « Déposez un fichier OFX, QFX ou CSV » / sub « ou cliquez pour parcourir — un CSV ouvre l'assistant de correspondance ». File-selected variant: iris-tinted dashed row with OFX format badge, filename + size, remove ×, and primary « Importer ». Region A' result Card (right, only after an import): « Dernier import » + Réussi status pill, two inset count plates (42 nouvelles / 3 doublons ignorés), coverage line 01/05/2026 – 31/05/2026 and file→account line. Region C « Historique des imports » (Card, fills remaining height): DataTable Fichier · Format badge (OFX blue / QFX violet / CSV amber) · Importé le · Période couverte · Nouvelles · Doublons · Statut pill (Réussi green / Partiel amber / Échec red); notes render as a second line under the filename (amber dup note, red failure message « Colonne montant introuvable — relancez l'assistant CSV, rien n'a été modifié »).

## States to show
① file selected + result (fr). ② CSV wizard (fr) — 780 px Modal over the panel: stepper (1 Format ✓ · 2 Colonnes & aperçu), 3×2 control grid (Délimiteur ; · Encodage Latin-1 · Format de date dd/MM/yyyy · Séparateur décimal , · Montants SegmentedControl Signé/Débit-Crédit · Lignes d'en-tête 1), three mapping plates (Col. A « Date opération » → Date, etc., iris arrows), 4-row live preview DataTable with signed colored amounts, save-template toggle « Mémoriser ce format pour Boursorama », footer Annuler / « Valider et importer (57 lignes) ». ③ history (fr) — 5 batches incl. Partiel-with-dups and Échec. ④ empty history (fr) — EmptyState inside Region C, DropZone above stays available.

## Notes
Failure copy is calm and states nothing was modified. Wizard defaults mirror French bank CSVs (;, Latin-1, dd/MM/yyyy, decimal comma).