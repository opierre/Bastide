---
name: versioning
description: Use whenever creating a new branch in Bastide, and before opening or merging a PR. Every new branch bumps the one product version — backend (pyproject + uv.lock) and frontend/app (pubspec) together — as its first commit. Defines the version scheme (release X.Y.Z, development X.Y.Z-dev.N, build number), which files to touch, how to resolve two branches claiming the same number, and how a release is cut.
---

# Versioning

Bastide ships **one product version**: the backend and the Flutter app go out in the same
installer, so they always carry the same number (see `SHIP.md` → "Why one version").
`backend/tests/test_version.py` fails when the two drift.

## The rule

**Every new branch bumps the version, in its own first commit, before any other work.**
Feature, fix, docs or chore: no exception. A merged branch is then identifiable by its version
in Settings → About, in `/health`, and in the `READY <port> <version>` line.

## The scheme

| State of `main` | Form | Example |
| --- | --- | --- |
| Released | `X.Y.Z` | `0.1.2` |
| In development toward the next release | `X.Y.Z-dev.N` | `0.1.3-dev.0`, `0.1.3-dev.1` |

The frontend adds a **build number** after `+` (`0.1.3-dev.0+4`). It is the installers' own
counter, not part of the product version.

## How to bump, from the version on `main`

1. **`main` is a release (`X.Y.Z`)**: open the next development cycle.
   `X.Y.Z` → `X.Y.(Z+1)-dev.0`, and **build number + 1**.
   `0.1.2+3` → `0.1.3-dev.0+4`
2. **`main` is a development version (`X.Y.Z-dev.N`)**: take the next development number.
   `X.Y.Z-dev.N` → `X.Y.Z-dev.(N+1)`, build number **unchanged**.
   `0.1.3-dev.0+4` → `0.1.3-dev.1+4`

Always start from the version **on `origin/main`** (`git fetch` first), never from another
open branch.

Don't pick the minor or major version on a feature branch: development bumps only move the
`-dev.N` counter. The release branch picks the final number (see "Cutting a release").

## Files: all three, in one commit

| File | Line | Spelling |
| --- | --- | --- |
| `backend/pyproject.toml` | `version = "0.1.3-dev.0"` | SemVer, like the pubspec (pip normalizes it to `0.1.3.dev0`) |
| `backend/uv.lock` | the `bastide-backend` package entry | regenerated with `uv lock` from `backend/`, never edited by hand |
| `frontend/pubspec.yaml` | `version: 0.1.3-dev.0+4` | SemVer + build number; this is the **app** version: the About screen and the installer names (`tools/package_app.py`) read it |

Nothing else carries the number. `app.__version__` reads installed package metadata, so run
`uv sync` after the bump for it to report the new version locally.

Verify:

```
cd backend && uv lock && uv sync && uv run pytest tests/test_version.py
```

Only our own package's entry changes, so `--offline` on `uv lock` / `uv sync` works when PyPI
is unreachable.

Commit (load **git-conventional-commits**):

```
chore(release): bump the development version to 0.1.3-dev.1
```

## Two branches, one number

Branches opened in parallel from the same `main` claim the same next number. The first one to
merge keeps it. Every other branch, before it merges:

1. rebases on (or merges) the new `main`,
2. resolves the conflict on the three version lines by taking `main`'s value,
3. **bumps again** from that value, in a new `chore(release)` commit.

So `main` never goes backwards and never sees the same number twice. Check this before every
merge, not only when git reports a conflict: a clean merge can still carry a stale number.

## Cutting a release

A release is its own branch (`chore/release-X.Y.Z`), so it follows the rule like any branch:

1. Drop the pre-release suffix: `0.1.3-dev.4+4` → `0.1.3+4` (or move to `0.2.0+4` when the cycle
   shipped features worth a minor version; that call is the user's). Build number unchanged.
2. Commit `chore(release): release 0.1.3`, merge, and tag `v0.1.3` on `main`: CI builds the
   installers from the tag.
3. The next branch opened after the release starts the new cycle (rule 1 above).

Never tag a `-dev` version as a release.

## Don'ts

- Don't bump inside a feature commit: the bump is always its own commit, so it can be reverted or
  re-done during a rebase without touching the work.
- Don't give the backend and the frontend different numbers.
- Don't reuse or lower a number that has reached `main`.
- Don't edit `uv.lock` by hand.
