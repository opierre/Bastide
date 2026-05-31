# Working in VS Code — Daily Workflow

How to actually build this app day to day: the editor setup, how to drive Claude Code against the
task cards cheaply, how to run both halves together, how to commit/roll back, how to advance
between phases, and where mockups live.

---

## 1. One-time setup

### Multi-root workspace
Open the monorepo as a **multi-root workspace** so both packages and the docs live in one window.
Create `finstride.code-workspace` at the repo root:

```jsonc
{
  "folders": [
    { "path": "backend" },
    { "path": "frontend" },
    { "path": "docs" },
    { "path": "." }          // root: CLAUDE.md, .claude/, skills
  ],
  "settings": {
    "editor.formatOnSave": true,
    "[python]": { "editor.defaultFormatter": "charliermarsh.ruff" },
    "[dart]":   { "editor.defaultFormatter": "Dart-Code.dart-code" }
  }
}
```

Open it via **File → Open Workspace from File…**. Each folder gets its own integrated terminal.

### Extensions
- **Python** (Microsoft) + **Ruff** (Astral) + **ty** (Astral) — backend lint/format/types.
- **Flutter** + **Dart** — frontend.
- **Claude Code** (or run the `claude` CLI in the integrated terminal).
- Optional: **SQLite Viewer** (inspect the local db), **Even Better TOML** (edit `pyproject.toml`).

### Toolchain check (run once per machine)
```bash
# backend
cd backend && uv sync          # creates the env from the lockfile
uv run ruff --version && uv run ty --version
# frontend
cd ../frontend && flutter doctor && flutter pub get
```

---

## 2. The Claude Code session model (this is the token lever)

Run **scoped sessions**, not one giant session over the whole repo. The package-level `CLAUDE.md`
files mean an agent started inside a folder automatically inherits root + package rules.

- **Backend card?** Start `claude` from `backend/`. It sees `backend/CLAUDE.md` + root.
- **Frontend card?** Start `claude` from `frontend/`.
- **Cross-cutting change** (e.g. an API-contract change touching both sides)? Start from the repo
  root so both folders are in scope.

Why: narrower context = fewer tokens and far less drift. A card that only touches
`backend/app/features/accounts/` does not need the Flutter tree loaded.

### Model choice per card
The cards are explicit enough to split work by difficulty:
- **Cheaper/faster model**: scaffolds, CRUD endpoints, straightforward UI panels
  (P1-00, 01, 02, 04, 05, 06, 07, 10, 12, 13).
- **Stronger model**: logic-heavy cards — the parsers (P1-08, 09), the rule engine (P1-11), the
  dashboard math (P1-14), and the DB/migration card (P1-03).

---

## 3. The run-a-card loop

Do this once per task card, in dependency order (see `docs/tasks/README.md`):

1. **Pick the next card** whose `Depends on` cards are all merged and green.
2. **Open a scoped terminal** in the right package folder; start `claude`.
3. **Point the agent at the card**, e.g.:
   > "Implement `docs/tasks/P1-06-accounts-backend.md`. Load the skills it lists. Do only its
   > scope. Make its tests pass and `ruff`/`ty` clean. Then commit with the commits it specifies.
   > If anything isn't covered by the card, the skills, or PROJECT.md, stop and ask me."
4. **Let it work**, then **review the diff** in VS Code's Source Control panel before committing.
5. **Run the checks yourself** to confirm:
   - backend: `uv run ruff check && uv run ty check && uv run pytest`
   - frontend: `flutter analyze && flutter test`
6. **Commit** per the card's Conventional Commits (the agent can do this; you approve).
7. Move to the next card.

Keep each card to its **own session** when practical — start fresh for the next card so context
stays small.

---

## 4. Running both halves together (dev)

You'll usually want the backend sidecar and the Flutter app running side by side. Use two
integrated terminals:

```bash
# Terminal A — backend (from backend/)
uv run uvicorn app.main:app --host 127.0.0.1 --port 8765 --reload

# Terminal B — frontend (from frontend/)
flutter run -d macos   # or -d windows / -d linux
```

Point the Flutter API client's base URL at `http://127.0.0.1:8765` in dev config. The backend
binds **loopback only** (per the architecture skill) — never `0.0.0.0`.

Optional convenience: add VS Code **tasks** (`.vscode/tasks.json`) for "Run backend" and
"Run frontend", and a compound **launch** config so one command starts both. Docker is available
for a reproducible dev DB/services later, but for local single-user dev the two commands above
are enough.

---

## 5. Commit & rollback flow

The Conventional Commits convention (see the `git-conventional-commits` skill) is what makes
rollback safe:

- **Inspect history**: `git log --oneline` — each commit is one logical change with a clear
  `type(scope): subject`.
- **Undo the last commit but keep the work**: `git revert <sha>` (safe, creates an inverse commit)
  — preferred on any shared branch.
- **Throw away uncommitted work** on a file: discard in the Source Control panel, or
  `git restore <path>`.
- **Roll back a whole feature**: because a card's commits are scoped to one feature, you can
  `git revert` that range without disturbing others.
- Never force-push shared history; fix forward.

Work each card (or sub-step) as its own commit so a bad change is a one-line revert, not an
archaeology project.

---

## 6. Moving to the next phase

Phase 1 is fully specced (`PROJECT.md` §2, all `P1-*` cards). Phases 2–4 are outlined but not yet
broken into cards — **on purpose**, so you don't spend tokens detailing work that earlier phases
might reshape. To advance:

1. **Close out the current phase.** Confirm its Definition of Done (`PROJECT.md` §11 + the phase
   row in §2): all cards merged, CI green, the end-to-end user flow works in fr + en. Tag it:
   `git tag v0.1.0-phase1 && git push --tags`.
2. **Re-open the planning loop with me** (or your planning agent) for the next phase. Bring this
   repo's `PROJECT.md`. We:
   - **Detail the schema stubs** for that phase (the Phase 2+ entities in §4: `goals`,
     `goal_allocations`, `mortgages`, `amortization_entries`, `tax_profiles`, `projections`).
   - **Add/extend skills** as needed (e.g. a `mortgage-amortization` skill, a `french-tax` skill;
     the `ai-categorization` skill already exists for Phase 2's SLM step).
   - **Write the next batch of task cards** (`P2-*`, then `P3-*`, `P4-*`) in the same format.
   - **Add design prompts** for the new panels (Goals, Mortgages, Taxes, Projection) reusing the
     same shared design block.
3. **Phase-specific notes:**
   - **Phase 2 (SLM):** install Ollama, pull the default model (Gemma 4 E4B). The
     `ai-categorization` skill already defines the rules→model→confidence→review flow and the
     graceful-degradation-without-Ollama requirement, so the cards mostly wire it up + build the
     review UI (the queue already exists from P1-13).
   - **Phase 3 (mortgages + tax):** tax logic changes yearly and is estimation-first — keep each
     fiscal year's rules versioned/dated so they can be updated without touching engine code.
   - **Phase 4 (multi-user + cloud sync):** this is where SQLite → PostgreSQL happens. Because the
     code went through SQLAlchemy + Alembic with integer-minor-units and per-account `currency`
     columns from day one (see `database` + `multi-currency` skills), it's a dialect/connection
     change plus the new sync/auth surface — not a rewrite. Per-account multi-currency + FX also
     lands here.

**Rule of thumb:** detail one phase at a time. Spec → skills → cards → design prompts → build →
tag → next phase. Don't pre-write `P3` cards while `P2` might still reshape the schema.

---

## 7. Where mockups live

Mockups from **Claude Design** or **Google Stitch** are reference artifacts (not code), but they
belong in the repo so design and build stay in sync. Store them under `docs/design/mockups/`:

```
docs/design/
├── 00-shared-design-block.md      # the binding spec
├── 01-tool-wrappers.md
├── 02-login.md … 07-transactions.md
└── mockups/
    ├── login/
    │   ├── login-en.png
    │   ├── login-fr.png
    │   └── login-error.png
    ├── dashboard/
    │   ├── dashboard-populated-fr.png
    │   ├── dashboard-populated-en.png
    │   └── dashboard-empty.png
    ├── accounts/ …
    ├── imports/ …            # include the CSV wizard + history states
    └── transactions/ …       # include the review-queue state
```

Conventions:
- **Naming**: `<panel>-<state>[-<locale>].png` (e.g. `transactions-review-fr.png`). States to
  capture: at least `populated`, `empty`, and any error/wizard state the panel prompt asked for.
- **Format**: PNG (or SVG/PDF if the tool exports vector) at the desktop canvas size (~1440×900).
- **Source links**: if a tool keeps an editable project (e.g. a Claude Design canvas URL), drop a
  `SOURCES.md` in the panel's folder with the link, so you can re-open and iterate rather than
  regenerate from scratch.
- **Large files**: if the PNGs get heavy, enable **Git LFS** for `docs/design/mockups/**` so the
  repo stays light. Commit them as `docs(design): add <panel> mockups`.
- **Keep them current**: when the shared design block changes (e.g. a palette tweak), regenerate
  the affected panel mockups so they don't lie about the built app. The mockups are documentation
  of intent; the `design-system` skill + `tokens.dart` remain the source of truth for the code.

A reasonable middle ground if the repo must stay lean: keep the **canonical, current** mockup per
panel/state in-repo, and archive exploratory variants in your design tool rather than committing
every iteration.
