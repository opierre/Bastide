# Phase 1 Task Cards

Atomic, self-contained units of work for AI agents. Each card implements one slice of
`PROJECT.md` against the skills in `.claude/skills/`. Cards are designed so a **small/cheap model
can execute one card precisely** without re-deriving project decisions.

## How to run a card (token-efficient protocol)

1. **One card per agent session.** Don't load the whole repo. Open the card + only the files it
   names. Narrow context = fewer tokens + less drift.
2. **Load the listed skills** (the `Skills` line). They carry the rules so the card stays short.
3. **Do exactly the card's scope.** If the card needs a decision it doesn't contain and the
   skills/`PROJECT.md` don't cover, **stop and ask** — don't invent.
4. **Meet every acceptance criterion and make the listed test pass.** A card isn't done until its
   tests are green and `ruff`/`ty` (backend) or `flutter analyze` (frontend) pass.
5. **Commit** with the Conventional Commit(s) named in the card (see `git-conventional-commits`).

Recommended model split: run backend/frontend cards in a session scoped to that package (see the
package-level `CLAUDE.md`). Use a capable model for the parser/dashboard cards (more logic) and a
cheaper model for CRUD/UI cards — the cards are explicit enough that this works.

## Card format

```
# P1-NN — Title
Scope: backend | frontend | both
Depends on: <card ids>
Skills: <skill names to load>
PROJECT.md: <sections this implements>

## Objective        one paragraph: what done looks like
## Files            exact paths to create/edit
## Contract slice   only the endpoints/fields this card touches
## Steps            ordered, concrete
## Acceptance       checklist, binary pass/fail
## Tests            the tests that must exist and pass
## Commits          the conventional commit(s) to make
```

## Sequence & dependency graph

```
P1-00 scaffold (root)
  ├─ P1-01 backend scaffold ──┐
  └─ P1-02 frontend scaffold  │
P1-03 db models + migrations + seed ─ (needs P1-01)
P1-04 auth backend ─ (P1-03)
P1-05 auth frontend ─ (P1-02, P1-04)
P1-06 accounts backend ─ (P1-04)
P1-07 accounts frontend ─ (P1-05, P1-06)
P1-08 import backend: OFX/QFX ─ (P1-06)
P1-09 import backend: CSV templates ─ (P1-08)
P1-10 import frontend ─ (P1-07, P1-08, P1-09)
P1-11 categories + rules backend ─ (P1-03, P1-06)
P1-12 transactions backend + rule engine ─ (P1-08, P1-11)
P1-13 transactions frontend ─ (P1-10, P1-12)
P1-14 dashboard backend ─ (P1-12)
P1-15 dashboard frontend ─ (P1-13, P1-14)
```

Build in numeric order; a card's `Depends on` must be merged & green first.

## Phase 1 definition of done

All cards merged; `PROJECT.md` §11 satisfied across the app; CI green (backend `ruff`+`ty`+
`pytest`, frontend `analyze`+`test`, ARB parity, migrations apply clean); a user can register
(locale+currency), add accounts, import OFX & CSV, see deduped transactions, rule-categorize
them, and view a dashboard with monthly income/expense, MoM trend, savings rate, and by-category
breakdown — in French and English.
