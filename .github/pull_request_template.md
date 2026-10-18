## What and why

<!-- What does this change do, and why? Link the issue it addresses. -->

Closes #

## How to test

<!-- Steps a reviewer can follow to see the change working. -->

## Screenshots

<!-- For UI changes: dark mode, in French and English if the text changed. Hide any personal data. Delete this section otherwise. -->

## Checklist

- [ ] Commits follow Conventional Commits (`type(scope): subject`), one logical change each
- [ ] Tests added or updated, with external dependencies mocked
- [ ] Backend checks pass: `ruff check`, `ruff format --check`, `ty check`, `pytest`
- [ ] Frontend checks pass: `flutter analyze`, `dart format`, `flutter test`
- [ ] Money stays in integer minor units; no floats
- [ ] No hard-coded user-facing text; French and English ARB files in parity
- [ ] `docs/database.md` and `docs/api.md` regenerated if a migration or route changed
- [ ] No real personal or financial data in code, tests, fixtures or screenshots
