# Task Cards

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
# P<phase>-NN — Title
Scope: backend | frontend | both | docs
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

Cards live in a per-phase folder: `Phase1/`, `Phase2/`.

## Phase 1 — sequence & dependency graph

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

## Phase 1 definition of done — **met**

All cards merged; `PROJECT.md` §11 satisfied across the app; CI green (backend `ruff`+`ty`+
`pytest`, frontend `analyze`+`test`, ARB parity, migrations apply clean); a user can register
(locale+currency), add accounts, import OFX & CSV, see deduped transactions, rule-categorize
them, and view a dashboard with monthly income/expense, MoM trend, savings rate, and by-category
breakdown — in French and English.

---

## Phase 2 — sequence & dependency graph

```
P2-01 user settings backend
  ├─ P2-02 Phase 2 models + migrations
  └─ P2-03 inference client + health
       └─ P2-04 stage-2 categorization service
            ├─ P2-05 run orchestration + import enqueue ─ (P2-02, P2-04)
            └─ P2-06 learning loop + rule preview
                 └─ P2-06b rule pack import/export + French starter pack
P2-07 categories & rules frontend ─ (P2-06, P2-06b)
P2-08 review queue: AI proposals + progress ─ (P2-05, P2-06, P2-07)
P2-09 settings frontend: local AI ─ (P2-01, P2-03)
P2-10 recurring detector ─ (P2-02)
  └─ P2-11 subscriptions API & lifecycle
       └─ P2-12 subscriptions frontend ─ (P2-11)
P2-13 goals backend ─ (P2-02)
  └─ P2-14 goals frontend + dashboard card ─ (P2-13)
```

The design frames exist — `docs/design/10-subscriptions.md`, `11-goals.md`, and the Phase 2
amendments in `00`, `04`, `07`, `09` are normative for every frontend card here. Three
independent tracks after P2-02 — **AI** (03→06, 08, 09), **subscriptions** (10→12), and **goals**
(13→14) — touching disjoint feature folders, so they can run in parallel.

### Phase 2 notes for agents

- The inference runtime is **not** pinned to Ollama. Everything above `features/inference/`
  speaks an OpenAI-compatible `/v1` API and must work against `llama-server` too — see
  `PROJECT.md` §3 for why, and never call a runtime-specific endpoint.
- **Nothing may block on the model.** Imports, the transaction list, and the dashboard must
  behave exactly as in Phase 1 when no runtime answers. Every card that touches AI carries an
  acceptance criterion for the absent-runtime path; it is not optional polish.
- The spec lives in `PROJECT.md` §4b (data model), §5b (API), §7 (run mechanics), §12 (recurring
  detection), §13 (goals). §12 and §13 are appended after §11 so the existing section numbers,
  which every skill and Phase 1 card cites, stay stable.
- **The drawn frames win over any card's prose.** Where a card describes a screen, it is
  summarising `docs/design/`; if the two disagree, follow the design file and say so in the PR.
  Cards were written before the frames came back and may lag them.

## Phase 2 definition of done

All P2 cards merged; `PROJECT.md` §11 satisfied per slice; CI green. With a local runtime
configured, a user can enable AI in settings, watch an import's unmatched rows get categorized in
the background, confirm or correct suggestions in the review queue, and turn a correction into a
rule that handles the next occurrence deterministically. They can manage categories and reorder
rules, see detected subscriptions with their monthly burden, price increases and missed charges,
and confirm/dismiss/cancel or declare one by hand. They can create savings goals and fund them
with signed allocations, with progress on the dashboard. They can import a shared rule pack —
and are offered the bundled French one after their first import — export their own rules, and
see how many transactions a pack would match before committing to it. **With no runtime
installed the whole app still works** and imports still arrive substantially categorized,
minus the AI affordances — in French and English.
