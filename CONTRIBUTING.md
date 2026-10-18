# Contributing to Bastide

Thanks for your interest in Bastide! Bug reports, ideas, translations and code are all welcome.
This page explains how to get a change merged. By taking part, you agree to follow the
[Code of Conduct](CODE_OF_CONDUCT.md).

## 🔒 Before anything: keep your data private

Bastide handles personal finances. **Never attach a real bank statement, database file
(`bastide.db`) or `.bastide` backup to an issue or pull request**, and don't paste real account
numbers, names or amounts. If a bug only shows up with a particular OFX file, cut it down to the
fewest transactions that still reproduce it and replace every identifier and amount with made-up
values.

## 💬 Issues

- **Bugs** — use the *Bug report* template. Say which version and OS you run, what you did, what
  you expected and what happened. The backend log (`logs/backend.log` in the data folder, see
  [`docs/install.md`](docs/install.md)) often helps; read it for personal data before sharing.
- **Ideas** — use the *Feature request* template and describe the problem before the solution.
  Bastide is local-first: proposals that need a bank connection, a cloud service or telemetry are
  out of scope.
- **Security issues** — don't open a public issue; see [Reporting a vulnerability](#-reporting-a-vulnerability).

Search the existing issues first; a 👍 on an existing one is more useful than a duplicate.

## 🛠️ Making a change

1. **Talk first for anything large.** For a new feature, a new dependency or a structural change,
   open an issue before writing code, so we can agree on the approach.
2. **Fork and branch** from `main`. Name the branch after the change, e.g. `fix/ofx-latin1` or
   `feat/goals-archive`.
3. **Set up** both halves as described in the [README quick start](README.md#-quick-start) and
   [`docs/development.md`](docs/development.md).
4. **Follow the project rules.** They live in [`CLAUDE.md`](CLAUDE.md), `backend/CLAUDE.md`,
   `frontend/CLAUDE.md` and the area guides in [`.claude/skills/`](.claude/skills/). They are
   written for coding agents but apply to everyone. The ones that come up most:
   - **Money is signed integer minor units** (cents), and rates are integer basis points. Never
     floats. Negative is an outflow, positive an inflow.
   - **No hard-coded user-facing text.** Every string goes through the ARB files, in French and
     English, and dates, numbers and currency are formatted for the locale.
   - **Feature-first layout.** A feature owns its routes, models and services in `backend/app/features/`,
     and its screens and state in `frontend/lib/features/`.
   - **Dark-first design** that follows [`docs/design/`](docs/design/). The sidebar and top bar
     stay identical on every panel.
   - **Loopback only.** The backend never binds anything other than `127.0.0.1`, and no feature
     may send data off the machine.
5. **Add tests** with every change, with the model, network, clock and filesystem mocked. See the
   [testing guide](.claude/skills/testing/SKILL.md).
6. **Regenerate the reference docs** if you touched a migration or a route. From `backend/`:
   ```bash
   uv run python -m scripts.schema_doc   # docs/database.md
   uv run python -m scripts.api_doc      # docs/api.md
   ```
   Never edit those two files by hand; a test fails when they are stale.
7. **Run the checks** CI runs, from each package folder:

   | Side | Command |
   |------|---------|
   | Backend | `uv run ruff check . && uv run ruff format --check . && uv run ty check && uv run pytest` |
   | Frontend | `flutter analyze && dart format --output=none --set-exit-if-changed lib test && flutter test` |

## ✍️ Commits

Commits follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): subject
```

- **type** is one of `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `build`, `ci`, `perf`.
- **scope** is the feature or area, e.g. `imports`, `transactions`, `dashboard`, `i18n`, `db`.
- **subject** is imperative and lower-case, with no trailing period: `fix(imports): read Latin-1 OFX headers`.
- **One logical change per commit**, leaving the build green. Keep refactors and formatting apart
  from behaviour changes, and keep both sides of an API change in the same commit.
- Add a `BREAKING CHANGE:` footer when a change breaks the API contract or the data schema.

The full rules are in the [commit guide](.claude/skills/git-conventional-commits/SKILL.md). The
release notes are built from these messages, so they matter.

## 🔀 Pull requests

- Open the pull request against `main` and fill in the template.
- Keep it focused: one feature or fix per pull request.
- The `ci-ok` check must pass. It runs lint, types, tests and the dependency and secret scanners
  on both halves.
- Include a screenshot or short recording for any UI change, in dark mode, and in French and
  English when the text changed.
- Expect review comments; push new commits to address them rather than force-pushing, so the
  conversation stays readable.

## 🤖 Using coding agents

Coding agents are welcome, and the repository is set up for them (see
[`docs/development.md`](docs/development.md#4-working-with-coding-agents)). You remain the author:
read and understand every line before you open the pull request, and make sure it follows the
rules above.

## 🛡️ Reporting a vulnerability

Please report security issues privately through
[GitHub's private vulnerability reporting](https://github.com/opierre/Bastide/security/advisories/new),
not in a public issue. Describe the problem and how to reproduce it; you'll get an answer as soon
as possible.

## 📄 License

Bastide is licensed under the [GNU Affero General Public License v3.0](LICENSE). By contributing,
you agree that your contributions are licensed under the same terms.
