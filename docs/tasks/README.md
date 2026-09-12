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

Cards live in a per-phase folder: `Phase1/`, `Phase2/`, `Phase3/`.

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

## Phase 2 definition of done — **met**

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

---

## Phase 3 — sequence & dependency graph

```
P3-01 phase 3 models + migrations
  ├─ P3-02 tax parameter + barème seeding
  ├─ P3-03 amortisation + TAEG engine
  │    └─ P3-04 mortgages API + debt ratio
  │         └─ P3-09 simulator API ─ (P3-03, P3-04)
  ├─ P3-05 properties API
  └─ P3-06 tax profiles API + ledger prefill
P3-07 tax estimation engine + endpoint ─ (P3-02, P3-05, P3-06)
P3-08 tax parameters API + override resolution ─ (P3-02)
P3-10 net-worth API ─ (P3-04, P3-05)
P3-11 Patrimoine nav group + routes ─ (P2-14)
P3-12 crédits panel ─ (P3-04, P3-11)
P3-13 impôts panel: declaration + estimate ─ (P3-07, P3-11)
  └─ P3-14 impôts panel: paramètres fiscaux view ─ (P3-08, P3-13)
P3-15 simulateur panel ─ (P3-09, P3-11)
P3-16 synthèse panel + properties management ─ (P3-05, P3-10, P3-11)
```

**P3-11 first among the frontend cards, and alone.** It is the only card that edits the shell
(`app_shell.dart`, `app_router.dart`); with it merged, the four panel cards touch disjoint feature
folders and can run in parallel. Two agents editing the sidebar is the one collision this phase
can easily avoid.

After P3-01 there are three independent backend tracks — **mortgages** (03 → 04 → 09), **tax**
(02 → 06/07/08) and **assets** (05 → 10) — with P3-10 the only join.

### Phase 3 notes for agents

- The spec lives in `PROJECT.md` §4c (data model), §5c (API), §15 (mortgages + debt ratio), §16
  (tax), §17 (simulator), §18 (net worth). §15–§19 are appended after §14 so the section numbers
  every skill and earlier card cites stay stable.
- **Nothing is derived twice.** Schedules, estimates, simulation results and net worth are computed
  on read from declared inputs — §4c retires `amortization_entries` and `projections` for exactly
  this reason. No card may add a column that caches one of them, and **no frontend card may
  reimplement one in Dart**: the Python engines are the ones with hand-computed tests.
- **Every rate is an integer in bps.** The percent the user types is converted at the form edge and
  nowhere else. No floats in the engines — `Decimal` for intermediates, integer minor units out.
- **The app makes no lending decisions and files no tax return.** An HCSF breach is displayed, never
  enforced; the tax estimate ships with the limits it did not model (§16 `ignored_keys`) beside the
  figure, not behind a tooltip. Cards carrying those statements are not carrying polish.
- **Tax parameters live in the Impôts panel**, not in Paramètres (§16): a number and its workings
  belong in the same panel.
- P3-02's job includes **verifying the seeded barème against the official source and recording the
  check in the migration**. A figure nobody sourced is every user's tax estimate a year later.
- **The drawn frames win over any card's prose.** The Phase 3 frames now exist —
  `docs/design/12-credits.md`, `13-impots.md`, `14-simulateur.md`, `15-synthese.md` and the Phase 3
  additions paragraph in `00-shared-design-block.md` are normative for every card here. The cards
  were written first and have since been reconciled against them; where any residue disagrees,
  follow `docs/design/` and say so in the PR.
- **Three Phase 3 questions are open and no card may answer them alone** (they surface as *stop and
  ask* steps in P3-12, P3-05 and P3-16): whether `mortgages` gains a product-`kind` column for the
  « Type » select the Crédits modal draws; whether a property keeps a valuation *history* rather
  than one declared value; and the parameter values and comparison figures the frames mark
  *« à fournir »* (`13-impots.md`, `14-simulateur.md`, `15-synthese.md` §Notes), which are mock
  data until the owner supplies them — P3-02 seeds from `PROJECT.md` §16 and the official source,
  never from a frame.
- §19 lists three Phase 3 questions that are **not decided** — runtime packaging, the insights
  feature, and whether an estimate can be exported. No card may claim them.

## Phase 3 definition of done

All P3 cards merged; `PROJECT.md` §11 satisfied per slice; CI green. A user can declare a mortgage
and read its full amortisation schedule with interest, principal and insurance separated, see the
total cost and an indicative TAEG, and see their debt ratio against the HCSF reference with the
income it was computed from named. They can declare the properties they own, with ownership shares
and valuation dates. They can fill a tax profile for a year — accepting ledger-derived suggestions
field by field, never silently — and read an estimate of IR, PFU or barème capital tax, social
charges, property income and IFI, broken down component by component, next to a plain statement of
what it did not model; and they can adjust any barème band or parameter for that year inside the
panel and reset to the official values. They can simulate a new loan, watch the figures follow
their inputs, read the HCSF verdict including their existing loans, and compare up to three saved
scenarios. They can see assets, liabilities and net worth in one panel, with the series honest
about held-flat property values and the exclusions stated. **In French and English**, with no
arithmetic duplicated in Dart and no derived figure stored in the database.
