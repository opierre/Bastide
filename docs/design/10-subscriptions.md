# 10 — Abonnements

Mockup: `#panel=subscriptions`. Ticket #211. Read `00-design-system.md` first.

## Title bar
Title « Abonnements ». Right: secondary « Détecter » (`scan-search`). There is no « Nouvel
abonnement »: a series is created from its charges with « Marquer comme récurrent » in
Transactions.

## Layout (list)
Standard padding. Top to bottom, 24 px apart:

1. **Summary line.**
2. **Merge suggestions** (only when there are any).
3. **Table**, taking the remaining height.

## Content

### 1. Summary line
| Item | Label | Figure | Caption |
|---|---|---|---|
| Lead | « Charge mensuelle » | `212,08 €` 40 px, neutral | « Trimestriels et annuels ramenés au mois » |
| 2 | « Actifs » | `7` 20 px | « 5 mensuels · 1 trimestriel · 1 annuel » |
| 3 | « Prochain prélèvement » | « Netflix, demain » 20 px | « 15,49 € · 15 mai 2026 » |
| 4 | « À regarder » | count 20 px, `warning` when > 0 | « 1 hausse · 1 prélèvement manquant ». Hidden at 0. |

A vertical hairline separates the lead from the rest only.

### 2. Merge suggestions
One Banner per proposed pair: `merge` icon · « « STREAMCO » et « STREAMCO - STREAMCO TV »
semblent être le même abonnement, renommé par la banque. » · ghost « Ce sont deux abonnements »
· secondary « Fusionner ». Banners stack 8 px apart. With more than one, a header row sits
above: `merge` + « 3 suggestions de fusion » 12 `textSecondary` and a ghost chevron that folds
them for the session. Past three banners the stack scrolls.

### 3. Table
| Column | Content |
|---|---|
| Abonnement | Monogram + name |
| Catégorie | Category label |
| Cadence | « Mensuel », « Trimestriel », « Annuel », « Irrégulier », `textSecondary` |
| Montant | right, neutral, unsigned (an expected charge, not a transaction) |
| Prochain | right, date `textSecondary`; « attendu le 5 mai » in `warning` when missed; « — » when cancelled |
| État | Status text, empty when healthy: `trending-up` `warning` « Hausse : 13,49 € → 15,49 € » · `clock-alert` `warning` « Prélèvement manquant depuis 9 jours » · neutral « Résilié, dernier prélèvement le 18 mars » |
| (menu) | `ellipsis`: Confirmer · Ignorer · Marquer comme résilié · Modifier |

Sorted by next charge, soonest first; cancelled series last and dimmed. Headers Abonnement,
Montant and Prochain are sortable. A row opens the series detail.

## Series detail
Title bar: crumb « Abonnements / », title = series name, right: secondary « Modifier »,
`ellipsis` menu.

Blocks separated by 24 px, a hairline, 24 px (`00` §1.2): the summary line, then the history
block. The banner of item 2 sits 24 px above the history block, with no hairline of its own;
the note of item 4 closes the history block.

1. Summary line: lead « Montant attendu » 40 px · « Cadence » 20 px · « Prochain
   prélèvement » 20 px, a vertical hairline between each item (`00` §7) · right-aligned 12
   `textSecondary`: category label, then « {account} · détecté depuis {mois} ».
2. When the price changed: a Banner with a `warning` `trending-up` icon: « Hausse : 13,49 € →
   15,49 € le 15 avr. 2026, soit +24,00 € par an. »
3. Block « Historique des prélèvements »: the step-line chart (`00` §9), 184 px tall. Value
   axis: two ticks only, the cheapest and the dearest charge (one tick when the price never
   moved). Date axis: one tick per charge; ticks turn vertical, then thin to every Nth charge,
   when they would collide; the chart never scrolls sideways. Hover card: date, signed amount
   in `negative`, and « 13,49 € → 15,49 € » in `warning` on the charge that stepped.
4. Note: « La série est déduite de ces prélèvements. Vérifiez-les avant de confirmer un
   changement. »

## Edit modal (480 px)
Title « Modifier le paiement récurrent ». Nom · Compte (read-only: a series cannot move
account) · Montant · Cadence (select) · Catégorie (select with the category label). Footer
« Annuler » · « Enregistrer ».

## Other modals (`00` §7)
- **Ajouter à « {série} »** (560 px): lead « Les opérations qui ne font partie d’aucune série,
  les plus proches en premier. »; a search field, the candidate charges as checkable rows
  (date, bank label in Geist Mono over the account, amount), link « Afficher plus ». Primary
  counts the selection: « Ajouter {n} opérations ».
- **Marquer comme récurrent** (520 px), the dialog `07-transactions.md` opens: the preview
  (confidence as status text with its reasons on one line, said once: no banner repeats them; proposed cadence and amount, checkable charges), link « Ajouter à
  une série existante… »; when the charge matches a series, the lead says so and the body links
  to it; the series picker puts « Retour à l’aperçu » as the left ghost action.

## States
| State | What shows |
|---|---|
| Populated | As above. |
| Menu open | The row menu as a popover. |
| Empty | Empty state: « Aucun paiement récurrent détecté » · « Bastide repère un paiement récurrent lorsqu’un prélèvement s’est répété trois fois. Importer davantage d’historique accélère la détection. » · primary « Détecter ». |
| Detection running | « Détecter » shows the spinner in both places; a toast gives the result. |
| After a merge | Toast « Abonnements fusionnés » / « Les prochains prélèvements des deux libellés iront dans « {name} ». » |
| Loading | Summary and row silhouettes. |
| English | « Monthly », « Missed charge for 9 days », « Monthly cost », `€15.49`. |

## Behaviour (kept)
- Detection is deduced from imported transactions (three or more repeats); « Détecter »
  re-runs it.
- Cancelled series stay listed, dimmed, and are excluded from the monthly charge.
- The monthly charge brings quarterly and yearly series back to one month.
- A merge is proposed only for two non-manual, non-dismissed series with the same cadence,
  amounts within 25 % and related labels. Both answers are remembered. The kept series is the
  one charged most recently; the old label becomes an alias.
- Merge suggestions are informational, never a warning.
- Nothing is shown in « État » for a healthy subscription.

## Copy
Delete `navSubscriptionsSubtitle`. `subscriptionsEmptyTitle`, `subscriptionDetailFootnote`,
`subscriptionDetailHistorySubtitle` per `00` §14. « Augmentation » becomes « Hausse ». New:
« À regarder », « Prélèvement manquant depuis {n} jours ».

**English.** « Charge » is one debit throughout the panel (« Next charge », « Missed charge »),
so the monthly total is a cost, and « Hausse » is a price rise, as in the « À regarder »
caption.

| Key | French | English |
|---|---|---|
| `subscriptionsBurdenLabel` | « Charge mensuelle » | « Monthly cost » |
| `subscriptionsActiveLabel` | « Actifs » | « Active » |
| `subscriptionsWatchLabel` | « À regarder » | « Worth a look » |
| `subscriptionSignalIncrease` | « Hausse : {from} → {to} » | « Price rise: {from} → {to} » |
| `subscriptionDetailIncrease` | « Hausse : {from} → {to} le {date}, soit {annual} par an. » | « Price rise: {from} → {to} on {date}, that’s {annual} a year. » |
| `subscriptionSignalCancelled` | « Résilié, dernier prélèvement le {date} » | « Cancelled, last charge on {date} » |
| `subscriptionActionCancel` | « Marquer comme résilié » | « Mark as cancelled » |

## Removed from v1
Three summary cards with the tinted hero, StatusPills, coloured 36 px monograms, table card
frame, uppercase table header, « Retour aux abonnements » link (the crumb replaces it), the
header card and stat trio of the detail.
