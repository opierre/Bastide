# 10 — Abonnements (Phase 2)

Everything below is exactly what the mockup frames `10-Abonnements — *` in `FinStride Phase 2 Mockups.dc.html` show. Colors, amounts, order, and positions are normative — do not invent. Tokens per `00-shared-design-block.md`.

## Nav
Sidebar entry « Abonnements » / "Subscriptions" in the Gestion group, order: Imports · Catégories · **Abonnements** · Objectifs (see 00 amendment). Icon: circular-arrow cycle, 1.5 px stroke, round caps (2 px stroke when active).

## Top bar (this panel)
Title « Abonnements » / "Subscriptions" + descriptor « Vos prélèvements récurrents, détectés automatiquement » / "Your recurring charges, detected automatically". Right, in order: secondary button « Détecter » / "Detect" (38 px, border `#232B38`), primary gradient button « Nouvel abonnement » / "New subscription", user pill.

## Content — list state

### Summary row — grid `1.25fr 1fr 1.2fr`, gap 18
1. **Charge mensuelle** (hero, the only iris-tinted card: `linear-gradient(160deg,rgba(139,140,249,.14),rgba(108,106,240,.05) 55%),#111620`, border `rgba(139,140,249,.35)`, label iris `#8B8CF9`) — value `212,08 €` (Space Grotesk 700, 29px); caption « Charges trimestrielles et annuelles ramenées au mois. Canal+ (résilié) exclu. »
2. **Abonnements actifs** — value `7`; caption « 6 mensuels · 1 trimestriel · 1 annuel — Canal+ résilié. »
3. **Prochain prélèvement** — value « Netflix — demain » (24px); caption `15,49 € · 15/05/2026`.

### Table Card (fills remaining height)
Header row 32 px uppercase `#5A6579`: (36 monogram) · Abonnement (flex) · Catégorie 150 · Cadence 90 · Montant 100 right · Prochain 150 right · Statut 230 right · (28 kebab). Rows 56 px, `#1A212C` separators, hover `#151B26`. 36 px radius-11 monogram chips (16 % alpha bg, full-color text). CategoryChip with icon, colors = category palette from 00. Exact rows in this order:

| Mono (color) | Abonnement | Catégorie | Cadence | Montant | Prochain | Statut |
|---|---|---|---|---|---|---|
| NF `rgb(90,169,255)` | Netflix | Loisirs | Mensuel | 15,49 € | 15/05/2026 | Augmentation · 13,49 € → 15,49 € (amber pill) |
| SP `rgb(47,181,116)` | Spotify Famille | Loisirs | Mensuel | 17,99 € | 22/05/2026 | — |
| FM `rgb(244,114,182)` | Free Mobile | Abonnements | Mensuel | 19,99 € | 04/06/2026 | — |
| ED `rgb(255,184,77)` | EDF | Logement | Mensuel | 89,00 € | 08/06/2026 | — |
| BF `rgb(163,230,53)` | Basic-Fit | Santé | Mensuel | 29,99 € | « attendu le 05/05/2026 » in `#FFB84D` | Prélèvement manquant · 9 jours de retard (amber) |
| AD `rgb(79,209,232)` | Adobe Creative Cloud | Autres | Trimestriel | 71,99 € | 02/08/2026 | — |
| MA `rgb(10,163,150)` | MAIF Habitation | Logement | Annuel | 187,44 € | 21/11/2026 | — |
| C+ `rgb(151,163,182)` | Canal+ (row opacity .55) | Loisirs | Mensuel | 24,99 € | — | Résilié · dernier prélèvement 18/03/2026 (gray pill `#1E2634`/`#97A3B6`) |

**Status pill**: 22 px, radius 11, 6 px dot in currentColor; amber = `#FFB84D` on `rgba(255,184,77,.14)`. Amounts are neutral `#EDF1F7` (they are expected charges, not signed transactions).

**Kebab menu** (open on Netflix in frame ①): 230 px popover, overlay surface `#19202B`, border `#232B38`, radius 14, shadow `0 18px 44px rgba(0,0,0,.55)`; items 34 px: Confirmer (green check) · Ignorer · Marquer comme résilié · Modifier.

## Detail state (frame ②, Netflix)
Iris back link « Retour aux abonnements ». Header Card: 48 px NF monogram · name (Space Grotesk 20) + Loisirs chip · sub « BNP — Compte courant · détecté depuis décembre 2025 » · right stat trio (Cadence Mensuel / Montant attendu 15,49 € / Prochain prélèvement 15/05/2026). Below: amber banner « Augmentation : 13,49 € → 15,49 € le 15/04/2026 — soit +24,00 € par an. » Then history Card « Historique des prélèvements », sub « Les transactions dont cette série est déduite · BNP — Compte courant »; table Date 140 / Montant 120 right / right-aligned change pill; rows (amounts red `#FF5C6C`): 15/04/2026 −15,49 € with amber pill « 13,49 € → 15,49 € » and row tint `rgba(255,184,77,.05)`; then 15/03, 15/02, 15/01/2026, 15/12/2025 at −13,49 €. Foot note: « FinStride déduit la série de ces occurrences — vérifiez-les avant de confirmer un changement. »

## Empty state (frame ③)
Centered: 64 px iris plate with cycle glyph; « Aucun abonnement détecté pour l'instant »; « FinStride repère un abonnement lorsqu'un prélèvement s'est répété trois fois. Importer davantage d'historique accélère la détection. »; gradient CTA « Aller aux imports ».

## New-subscription modal (frame ④, over list)
480 px modal on `rgba(4,6,11,.62)` scrim. Title « Nouvel abonnement », sub « Suivez un prélèvement que la détection n'a pas encore repéré. » Fields: Nom (focused: iris border + focus ring) = Basic-Fit; row Compte (select, BNP — Compte courant) + Montant 130 px (29,99 €); row Cadence (select « Mensuel », help « Mensuel · Trimestriel · Annuel · Irrégulier ») + Catégorie (select with swatch, Santé). Footer right: Annuler (secondary) · Créer l'abonnement (gradient).

## States to show
① liste (fr, kebab open on Netflix) ② détail série (fr) ③ vide (fr) ④ modal création (fr) ⑤ liste (en) — same geometry; EN strings per mockup (Monthly/Quarterly/Yearly, `€15.49`, "May 15, 2026", "Missed charge · 9 days late", "Cancelled · last charge Mar 18, 2026").

## Notes
Detection is deduced from imported transactions (3+ repeats); « Détecter » re-runs it manually. Cancelled subscriptions stay listed (dimmed) and are excluded from the monthly-burden figure. Statut column is empty for healthy subscriptions — no "OK" pill.
