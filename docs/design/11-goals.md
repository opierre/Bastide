# 11 — Objectifs (Phase 2)

Everything below is exactly what the mockup frames `11-Objectifs — *` in `FinStride Phase 2 Mockups.dc.html` show. Colors, amounts, order, and positions are normative — do not invent. Tokens per `00-shared-design-block.md`.

## Concept (binding)
Goals are **virtual envelopes** — on-paper allocations that never modify accounts and never create transactions. A goal is NOT linked to any specific account: no account is shown anywhere on a goal card, in the detail header, or in the allocation modal. The only account-level fact used is the aggregate savings total for the over-allocation banner.

## Nav
Sidebar entry « Objectifs » / "Goals", last of the Gestion group. Icon: flag/fanion (pole + pennant), 1.5 px stroke (2 px active).

## Top bar (this panel)
Title « Objectifs » / "Goals" + descriptor « Mettez de côté, virtuellement, pour ce qui compte » / "Set money aside, virtually, for what matters". Right: primary gradient button « Nouvel objectif » / "New goal", user pill.

## Grid state (frames ① fr / ⑤ en)
Top to bottom:
1. Reassurance line (12 px `#5A6579`, lock glyph): « Répartition sur le papier : vos comptes ne sont pas modifiés. » / "On-paper allocation: your accounts are not modified."
2. Info banner (blue `#5AA9FF` on `rgba(90,169,255,.09)`, border `rgba(90,169,255,.3)`, dismiss ×): « Vous avez réparti 24 450,00 € alors que vos comptes d'épargne totalisent 22 100,00 €. » Shown only when over-allocated.
3. **GoalCard grid** — 2 columns, gap 18. GoalCard: raised Card, radius 16, padding 20/24, hover border `#3A4556`; name (Space Grotesk 16/700) + right pill; value line `saved` (Space Grotesk 24, tabular) « / target » (13 `#97A3B6`) + right percent (14/700); 8 px progress bar, track `#1E2634`, fill `linear-gradient(90deg,#6C6AF0,#8B8CF9)`. **No account line.** Exact cards, this order:

| Objectif | Épargné / Cible | % | Pill |
|---|---|---|---|
| Fonds d'urgence | 6 400,00 € / 10 000,00 € | 64 % iris | « Sans échéance » gray (`#1E2634`/`#97A3B6`) |
| Apport immobilier | 12 800,00 € / 30 000,00 € | 43 % iris | « Juin 2028 » gray |
| Voyage Japon | 4 000,00 € / 4 000,00 € | 100 % **green `#4ADE80`** | green check pill « Objectif atteint · Juin 2026 » (`#4ADE80` on `rgba(74,222,128,.12)`); card gets iris-tint bg + border `rgba(74,222,128,.35)` |
| Nouvelle cuisine | 1 250,00 € / 8 000,00 € | 16 % iris | « Décembre 2026 » gray |

4. **Archived-goals link** below the grid (12.5 px 600 `#97A3B6`, hover `#EDF1F7`, archive-box icon): « Afficher les objectifs archivés (2) » / "Show archived goals (2)". Clicking reveals archived goals (dimmed GoalCards) in place; count reflects reality.

## Detail state (frame ②, Fonds d'urgence)
Iris back link « Retour aux objectifs ». Header Card: 96 px progress ring (same recipe as SavingsRateCard: viewBox 0 0 100 100, r 40, stroke 10, track `#1E2634`, iris arc rotate(-90), center text « 64 % » iris Space Grotesk 20) · name + sub « Sans échéance » (no account) · value `6 400,00 €` / `10 000,00 €` · right buttons: secondary **« Archiver »** (archive-box icon, border `#232B38`) then gradient « Nouvelle allocation ». Below: the reassurance lock line, then allocation Card « Historique des allocations », sub « Une seule liste, montants signés — un retrait est une ligne négative. » Table Date 140 / Montant 120 right / Note: 01/05/2026 +300,00 € green « Virement mensuel » · 01/04/2026 +300,00 € green « Virement mensuel » · 12/03/2026 −150,00 € red « Réparation voiture » · 01/03/2026 +300,00 € green « Virement mensuel ». Foot note: « Aucune transaction n'est créée : ces lignes n'existent que sur le papier de l'objectif. »

## Allocation modal (frame ③, over detail)
440 px modal, scrim `rgba(4,6,11,.62)`. Title « Nouvelle allocation », sub « Fonds d'urgence » (goal name only — no account). Fields: Montant (focused) = 300,00 €, help « Un montant négatif retire de l'objectif. » · Date 140 px = 14/05/2026 · Note (optionnelle), placeholder « Ex. Virement mensuel ». Footer: Annuler · Ajouter (gradient). One signed amount field — no separate deposit/withdraw modes.

## Empty state (frame ④)
Centered: 64 px iris plate with flag glyph; « Donnez un nom à ce qui compte »; « Un objectif est une enveloppe virtuelle : vous y mettez de côté à votre rythme, sans toucher à vos comptes. »; gradient CTA « Nouvel objectif ».

## Archiving (behavior)
« Archiver » (detail header) archives the goal: it leaves the active grid and the dashboard Objectifs card, keeps its history, and is listed via the archived-goals link. Archived goals can be unarchived from the same view. Reached goals are NOT auto-archived — the user decides.

## States to show
① grille (fr) ② détail + allocations (fr) ③ modal nouvelle allocation (fr) ④ vide (fr) ⑤ grille (en).

## Notes
Percent color: iris `#8B8CF9` in progress, green `#4ADE80` at 100 %. Progress > 100 % caps the bar at 100 % but shows the real percent. Allocation amounts follow the money rule (green +, red −, U+2212).
