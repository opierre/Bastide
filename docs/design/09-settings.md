# 09 — Settings

## Top bar (this panel)
Title « Paramètres » / "Settings" + descriptor « Profil, préférences et vos données locales ». Right: user pill only.

## Content layout
Left section nav, 210 px, 38 px radius-12 items: Profil · Préférences (active, iris tint) · Données · À propos. Right column (max 640 px) of grouped Cards for the Préférences panel: (1) Langue — SegmentedControl Français/English + note « S'applique immédiatement à toute l'interface. » (2) Devise — read-only dashed field « EUR (€) — Euro » with lock glyph + note « Choisie à l'inscription et appliquée à tous vos comptes. Elle ne peut pas être modifiée dans cette version. » (3) Aperçu des formats — two inset plates previewing Dates (14/05/2026) and Montants (1 234,56 €) in the active locale.

## States to show
① preferences (fr). ② preferences, English (en) — identical geometry re-rendered: English segment active, previews flip to May 14, 2026 / €1,234.56, all chrome strings switch (incl. the sidebar privacy badge "All data stays on this device").

## Notes
Profil (name/email/password), Données (database location, « Recalculer les soldes » with last-run timestamp — surfaced meanwhile on 05's summary —, export, danger zone) and À propos (version + local-privacy statement) reuse the same grouped-Card pattern; only Préférences was drawn in Phase 1 frames.