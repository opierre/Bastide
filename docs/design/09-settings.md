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