# P1-00 — Monorepo scaffold & agent config
Scope: both
Depends on: —
Skills: architecture, git-conventional-commits
PROJECT.md: §3

## Objective
Create the monorepo skeleton, agent config, and ignore rules so all later cards have a home.
No app logic yet — structure + config only.

## Files
- `CLAUDE.md` (root) — global conventions: stack versions (Python 3.14, uv, ruff, ty; Flutter +
  Riverpod), Conventional Commits, dark-first, i18n fr/en, money = integer minor units, "load the
  relevant skill before working", "stop and ask if a decision isn't covered".
- `backend/CLAUDE.md` — points to fastapi-backend + database + testing skills; uv/ruff/ty loop.
- `frontend/CLAUDE.md` — points to flutter-frontend + design-system + i18n-l10n + testing skills.
- `.claude/settings.json` — shared Claude Code config (skills dir enabled).
- `.gitignore` — Python (`__pycache__`, `.venv`, `*.db`, `.env`), Dart/Flutter (`.dart_tool`,
  `build/`), OS noise, coverage.
- `README.md` — one-paragraph project description + how to run dev (backend sidecar + flutter).
- `docs/` , `.claude/skills/` present (skills already authored).

## Steps
1. Create the directory tree from `PROJECT.md` §3 (empty `backend/app/...`, `frontend/lib/...`
   package folders can be created by their scaffold cards; here create top-level dirs + the files
   above).
2. Write the three `CLAUDE.md` files (root + 2 packages). Keep them short — they point to skills,
   they don't restate them.
3. Write `.gitignore`.
4. `git init` if needed; ensure `.claude/skills/` and `docs/` are tracked.

## Acceptance
- Tree matches `PROJECT.md` §3.
- Root + package `CLAUDE.md` exist and reference the correct skills.
- `.gitignore` excludes envs, build output, and the local SQLite db.
- No secrets committed.

## Tests
- N/A (scaffold). Verify `git status` is clean after commit and ignored paths are ignored.

## Commits
- `chore: scaffold monorepo structure and agent config`
