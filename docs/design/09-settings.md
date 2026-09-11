# 09 — Settings

## Top bar (this panel)
Title « Paramètres » / "Settings" + descriptor « Profil, préférences et vos données locales ». Right: user pill only.

## Content layout
Left section nav, 210 px, 38 px radius-12 items: Profil · Préférences (active, iris tint) · Données · À propos. Right column (max 640 px) of grouped Cards for the Préférences panel: (1) Langue — SegmentedControl Français/English + note « S'applique immédiatement à toute l'interface. » (2) Devise — read-only dashed field « EUR — € — Euro » with lock glyph + note « Choisie à l'inscription et appliquée à tous vos comptes. Elle ne peut pas être modifiée dans cette version. » (3) Aperçu des formats — two inset plates previewing Dates (14/05/2026) and Montants (1 234,56 €) in the active locale.

## States to show
① preferences (fr). ② preferences, English (en) — identical geometry re-rendered: English segment active, previews flip to May 14, 2026 / €1,234.56, all chrome strings switch (incl. the sidebar privacy badge "All data stays on this device").

## Notes
Profil (name/email/password), Données (database location, « Recalculer les soldes » with last-run timestamp — surfaced meanwhile on 05's summary —, export, danger zone) and À propos (version + local-privacy statement) reuse the same grouped-Card pattern; only Préférences was drawn in Phase 1 frames.

## Phase 2 amendment — IA locale (tab Données)
Normative reference: frames `09-Paramètres — IA locale, *` in `FinStride Phase 2 Mockups.dc.html`. The local-AI configuration lives in the **Données** tab (active in these frames — NOT Préférences), as a grouped Card « IA locale » alongside the tab's other content (database location, recalcul, export, danger zone — the Phase 2 frames draw only the IA card).

**Card anatomy, top to bottom:**
1. Header row: title « IA locale » 14/700 + sub « Activer la catégorisation par IA » 12 `#97A3B6`; right: 34×20 Toggle (on = iris).
2. Privacy callout (iris tint `rgba(139,140,249,.08)`, border `rgba(139,140,249,.25)`, lock glyph): « Les descriptions de vos transactions sont envoyées à un modèle qui s'exécute sur cet ordinateur. **Rien ne quitte votre machine.** » This callout is the card's centerpiece — always visible when the card is.
3. Field row (flex 1.3 / 1): **Adresse du moteur** — monospace field `http://127.0.0.1:11434/v1`, help « Adresse locale uniquement — 127.0.0.1 ou localhost. » (non-local addresses are rejected) · **Modèle** — select, monospace value `gemma3n:e4b`, help « Liste fournie par le moteur — saisie manuelle possible. » When no engine: dashed read-only field « — », help « Aucun modèle — moteur injoignable. »
4. **Seuil de confiance — 80 %** — Slider (see 00 §Phase 2): 300 px, track #1E2634, iris gradient fill to 80 %, 16 px thumb. Help: « En dessous de ce seuil, la transaction vous est proposée pour vérification plutôt que classée automatiquement. »
5. Status row behind a #1A212C divider: connected = 8 px green dot + « Connecté — 3 modèles disponibles » `#4ADE80`; no engine = amber dot + « Aucun moteur détecté à cette adresse. » + underlined iris « En savoir plus ». Right: secondary button « Tester la connexion » (34 px).

**Phase 2 states**: ③ IA locale, connecté (fr) ④ IA locale, aucun moteur détecté (fr).

**Rules**: engine address accepts loopback only; the threshold drives the 07 review-queue behavior; disabling the toggle returns 07 to its Phase 1 rendering with the calm invitation banner. Language/Devise/Formats stay in Préférences, unchanged.

## Phase 2 amendment — Sauvegarde et restauration (tab Données)
Normative reference: frames `09-Paramètres — Sauvegarde, *` in `FinStride Phase 2 Mockups.dc.html`. A second grouped Card in the **Données** tab, directly under « IA locale », same Card pattern (radius 16, `#111620` on `#242E3E`, padding 16/22, title 14/700 + sub 12 `#97A3B6`, right column max 640 px, section nav with « Données » active).

**Card anatomy, top to bottom:**
1. Header: « Sauvegarde et restauration » + sub « Exportez toutes vos données dans un fichier que vous pourrez réimporter. »
2. Export row — inset plate on the field surface `#0A0F15`, border `#1A212C`, radius 14, padding 12/14: 36 px iris-tint tile with the download-to-tray line icon · label « Exporter toutes les données » 13/700 · caption 12 `#97A3B6` « Fichier .finstride — comptes, transactions, catégories, règles, objectifs, paramètres. » · right: PrimaryButton « Exporter » (34 px, radius 11, iris gradient, ink `#0E1030`). Below the plate, 11.5 `#5A6579` tabular: « Dernière sauvegarde : 11/09/2026 à 14:32 » or « Aucune sauvegarde pour l'instant. »
3. Privacy callout (iris tint `rgba(139,140,249,.08)` / border `.25`, lock glyph): « Le fichier n'est pas chiffré. Conservez-le en lieu sûr — il contient tout votre historique financier. »
4. Restore row behind a `#1A212C` divider: « Restaurer une sauvegarde » 13/700 + sub « Remplace toutes les données actuelles. » · right: SecondaryButton « Importer un fichier… » (34 px, upload-from-tray line icon).

**States**: ⑤ idle — last-backup line shown. ⑥ export en cours — « Exporter » at 55 % opacity, `cursor:not-allowed`, 13 px spinner (2 px ring, ink-coloured arc) before the label; caption becomes « Préparation de l'archive… ». ⑦ export terminé — bottom-right Toast (green check disc) « Sauvegarde enregistrée — 1 284 transactions, 4 comptes. »; last-backup line updates to the new timestamp. ⑧ confirmation de restauration — Modal 500 px, radius 20, `#19202B`: title « Restaurer cette sauvegarde ? » (Space Grotesk 17/700) · subtitle « Fichier sélectionné : » + file name in monospace · inset summary plate (`#0A0F15`, radius 14, 36 px rows, tabular figures): Exporté le · Version de l'application (monospace) · Comptes · Transactions · Catégories · Règles · Abonnements · Objectifs · warning callout (`rgba(255,184,77,.08)` / border `.35`, triangle icon) « Toutes vos données actuelles seront remplacées. Exportez-les d'abord si besoin. » · buttons « Annuler » (secondary) + « Remplacer mes données » (solid `#FF5C6C`, ink `#2A0A0F`, destructive). ⑨ restauration refusée — InlineErrorBanner inside the card, under the privacy callout (`rgba(255,92,108,.08)` / border `.32`, circle-i icon): bold red lead « Restauration impossible. » + « Ce fichier provient d'une version plus récente de FinStride. Mettez l'application à jour pour le restaurer. »

**Rules**: the export button is disabled while an archive is being prepared; a restore always goes through the confirmation modal, and the destructive red appears only there — never on the card. The archive schema carries the app version; a file from a newer version is rejected (⑨) before any data is touched. No emoji, line icons only.
