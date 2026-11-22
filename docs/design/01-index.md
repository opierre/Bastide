# 01 — How to use these specs

| File | Screen | Mockup `#panel=` | Ticket |
|---|---|---|---|
| `00-design-system.md` | Tokens, components, voice. Binding for everything below. | `system` | #198 |
| `02-login.md` | Connexion | `login` | #204 |
| `03-register.md` | Inscription | `register` | #204 |
| `04-dashboard.md` | Tableau de bord | `dashboard` | #205 |
| `05-accounts.md` | Comptes | `accounts` | #206 |
| `06-imports.md` | Imports | `imports` | #209 |
| `07-transactions.md` | Transactions | `transactions` (`variant=A` Toutes, `variant=B` À vérifier) | #208 |
| `08-categories-rules.md` | Catégories et règles | `categories` | #210 |
| `09-settings.md` | Paramètres | `settings` (`variant=A` to `D`) | #216 |
| `10-subscriptions.md` | Abonnements | `subscriptions` | #211 |
| `11-goals.md` | Objectifs | `goals` | #212 |
| `12-credits.md` | Crédits | `loans` | #213 |
| `14-simulateur.md` | Simulateur | `simulator` | #214 |
| `15-synthese.md` | Synthèse | `networth` | #215 |
| `16-account-detail.md` | Détail d’un compte | `account` | #207 |
| `17-placements.md` | Placements (new) | `investments` | #217, #218 |
| `18-brand.md` | Logo, texture, installer splash, startup screen | `logos`, `textures`, `splash` | #202 |

(13 was the tax panel, dropped.)

## Reading a panel spec

1. Read `00-design-system.md` first. A panel spec never restates a token or a component recipe;
   it names the component (« Summary line », « Table », « Inspector pane », « repère ») and says
   what goes in it.
2. Open the mockup at `proposal_v6/index.html#panel=<id>&theme=dark` (or `light`). The mockup
   shows one state; the spec lists all of them.
3. **Structure is binding, sample data is not.** Names, amounts and dates in the mockup and in
   the specs are invented examples (persona Camille Dubois, May 2026, EUR). Never copy real
   user data into code, tests or docs.
4. Every spec has the same sections: Title bar, Layout, Content, States, Behaviour, Copy,
   Removed from v1. « Behaviour » carries the functional rules that already ship and must be
   kept. « Removed from v1 » lists what the rebuild deletes.
5. If something is not covered, stop and ask (CLAUDE.md, principle 2). Do not fill a gap with a
   v1 habit: no card, pill, tinted plate, gradient, uppercase label or subtitle.

## Build order

`00` (#198) → tokens (#199) → shared widgets (#200) → shell (#201) → the panels in any order.
Brand (#202) and copy (#203) depend only on `00`. Placements needs its backend (#217) first.

## Definition of done for a panel

- Matches its spec in dark and light, at 1440 × 900, and with the sidebar collapsed.
- Every state listed under « States » exists and has a widget test.
- No colour, size or radius literal in the panel's files.
- fr and en strings at parity; the strings under « Copy » are applied.
- Everything under « Removed from v1 » is gone from the code.
