# FinStride

A desktop-first personal finance manager (French-first, English second). Import your bank data
via OFX/QFX/CSV — no direct bank connections — and get a clear, encouraging view of your money:
accounts, transactions, monthly income/expense with trend, categories, savings rate, and (in
later phases) goals, mortgages, French tax estimation, and projections. Local-first and
privacy-first: all data and AI run on your machine.

> **New here? Read [`PROJECT.md`](PROJECT.md) first.** It is the single source of truth for scope,
> architecture, schema, API contract, and conventions. Everything else points back to it.

## Stack

- **Frontend:** Flutter (desktop), Riverpod, intl + ARB localization (fr/en)
- **Backend:** Python 3.14 + FastAPI, run as a localhost **sidecar**; uv · ruff (lint+format) · ty (types)
- **Data:** SQLite (WAL) via SQLAlchemy + Alembic — built Postgres-ready for the future cloud tier
- **AI (Phase 2):** Ollama, local SLM (default Gemma 4 E4B), optional — degrades gracefully if absent
- **Deploy:** Docker for dev, native installers for end users

## Repo map

```
finstride/
├── PROJECT.md              ← START HERE: scope, architecture, schema, API, standards
├── README.md               ← you are here
├── CLAUDE.md               global agent conventions (+ backend/ and frontend/ have their own)
├── .claude/
│   └── skills/             the rule set every agent loads (see below)
├── docs/
│   ├── tasks/              Phase 1 task cards + README (execution protocol)
│   ├── design/             design-tool prompts + mockups/
│   └── vscode-workflow.md  day-to-day build workflow & phase transitions
├── backend/                FastAPI sidecar (feature-first; see architecture skill)
└── frontend/               Flutter desktop app (feature-first)
```

## How this project is built

The expensive thinking is written **once** into durable artifacts; cheap/local models then
execute against them. This keeps token usage low without losing precision.

1. **[`PROJECT.md`](PROJECT.md)** — the spec.
2. **Skills** in [`.claude/skills/`](.claude/skills/) — enforceable rules, each stated once and
   cross-referenced:
   `architecture`, `database`, `git-conventional-commits`, `fastapi-backend`, `flutter-frontend`,
   `ofx-csv-import`, `ai-categorization` (Phase 2-ready), `i18n-l10n`, `multi-currency`,
   `testing`, `design-system`.
3. **Task cards** in [`docs/tasks/`](docs/tasks/) — atomic, self-contained units. Each names the
   files, the slice of the spec it implements, the skills to load, acceptance criteria, and the
   test that must pass. See [`docs/tasks/README.md`](docs/tasks/README.md) for the sequence and
   the run-a-card protocol.
4. **Design prompts** in [`docs/design/`](docs/design/) — a shared design block + per-tool
   wrappers (Claude Design / Google Stitch) + one prompt per panel.

## Phased roadmap (see `PROJECT.md` §2)

- **Phase 1 (current target):** auth (locale + currency at registration) · multi-account ·
  OFX/QFX/CSV import + history · transactions · rules-based categorization · dashboard
  (income/expense, MoM trend, savings rate, by-category). Fully specced as `P1-*` cards.
- **Phase 2:** local SLM categorization + review queue · subscriptions · savings goals.
- **Phase 3:** mortgages/amortization · French tax estimation (IR + IFI + capital gains/dividends/
  property) · new-mortgage projection simulator.
- **Phase 4:** multi-user · optional cloud sync (→ PostgreSQL) · per-account multi-currency + FX.

Detail one phase at a time. The procedure to advance is in
[`docs/vscode-workflow.md`](docs/vscode-workflow.md) §6.

## Quick start (dev)

```bash
# clone, then open the multi-root workspace
code finstride.code-workspace

# backend (terminal A)
cd backend && uv sync
uv run uvicorn app.main:app --host 127.0.0.1 --port 8765 --reload

# frontend (terminal B)
cd frontend && flutter pub get
flutter run -d macos        # or windows / linux
```

The backend binds **loopback only**. Point the frontend's dev API base URL at
`http://127.0.0.1:8765`.

### Building it with agents
Work one task card per scoped Claude Code session, in dependency order, loading the skills the
card lists. Full loop, model-per-card guidance, commit/rollback, and phase transitions are in
[`docs/vscode-workflow.md`](docs/vscode-workflow.md). First card: `docs/tasks/P1-00-scaffold.md`.

## Conventions (enforced by skills)

- **Money:** signed integer minor units + ISO-4217 currency code — never floats.
- **Commits:** Conventional Commits (`type(scope): subject`), one logical change each.
- **i18n:** no hardcoded user-facing strings; fr + en parity from day one.
- **Tests:** every feature slice ships with tests; external deps (model, network, clock, FS) are
  mocked. CI: backend `ruff`+`ty`+`pytest`, frontend `analyze`+`test`, ARB parity, migrations apply.
- **Layout invariant:** the navbar / top bar / bottom bar are identical on every panel.

## License

TBD.
