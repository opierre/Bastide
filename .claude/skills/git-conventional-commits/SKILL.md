---
name: git-conventional-commits
description: Use whenever committing code, splitting work into commits, or writing commit/PR messages in the finstride. Defines the Conventional Commits format, the allowed types, the feature-based scope vocabulary, the one-logical-change-per-commit rule, and how to keep history clean and rollback-friendly. Consult before every commit.
---

# Git — Conventional Commits

Every change is committed as one or more Conventional Commits so history is readable and any
change can be rolled back cleanly.

## Format

```
<type>(<scope>): <subject>

[optional body — the WHY, wrapped at ~72 cols]

[optional footer — BREAKING CHANGE:, refs]
```

- **subject:** imperative mood, lower-case, no trailing period, ≤ ~72 chars
  ("add", not "added"/"adds").
- **body:** explain *why* and any non-obvious *what*. Skip for trivial changes.
- Reference the issue or PR when relevant (e.g. `refs: #42`).

## Allowed types

| type | use for |
|------|---------|
| `feat` | a user-facing capability or new behaviour |
| `fix` | a bug fix |
| `docs` | docs only (README, docs/, skills, comments-only) |
| `refactor` | code change that neither fixes a bug nor adds a feature |
| `test` | adding or correcting tests only |
| `chore` | tooling, deps, config, scaffolding with no app behaviour change |
| `build` | build system, packaging, installers, Dockerfile |
| `ci` | CI pipeline config |
| `perf` | a change made specifically to improve performance |

Do **not** invent other types.

## Scope = feature or area

Scope is the feature name or area touched. Canonical scopes:

`auth`, `accounts`, `imports`, `transactions`, `categories`, `rules`, `dashboard`, `api`,
`db`, `i18n`, `theme`, `core`, `deps`, `release`.

Examples:
```
feat(imports): parse OFX STMTTRN records into the canonical model
fix(transactions): correct sign on debit-column CSV amounts
refactor(accounts): move balance delta logic into the service layer
test(rules): cover priority ordering and first-match-wins
docs(architecture): document the layering direction
chore(deps): pin ruff and ty versions
```

## One logical change per commit

- A commit should do **one thing** and leave the build/tests green. If a sentence describing the
  commit needs an "and", it's probably two commits.
- Keep frontend + backend changes for the *same* API contract change together (one
  `feat(api): ...` commit) so the two sides never sit in a drifted state in history.
- Don't mix formatting/refactor noise with behaviour changes — separate `refactor`/`chore`
  commits keep `feat`/`fix` diffs reviewable and revertable.

## Breaking changes

Add a footer when a change breaks the API contract or data schema:
```
BREAKING CHANGE: accounts now require a currency; existing rows need migration <id>.
```

## Agent workflow (token-efficient, rollback-friendly)

1. Complete one slice of work.
2. Stage only the files for that logical change (`git add -p` when a working tree has mixed
   changes — never blanket `git add .` across unrelated work).
3. Commit with the correct `type(scope): subject`.
4. If a slice produces several logical changes (e.g. migration, model, service, tests),
   prefer **several focused commits** over one fat commit — this is what makes selective
   rollback possible.
5. Never amend or force-push shared history; fix forward with a new commit.

## What not to commit

- Secrets, local `.env`, the SQLite db file, build artifacts, `__pycache__`, `.dart_tool`,
  coverage output. Keep `.gitignore` authoritative.
- Generated files only if the project decides to vendor them (note it in the body).
