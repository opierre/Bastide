---
name: github-project-board
description: Run any GitHub Projects (v2) board as a Jira-style kanban with the gh CLI - plan a release/version/sprint into a milestone plus tracking issue and tickets, create/edit/prioritise/size issues, move cards between columns, link sub-issues and "blocked by" dependencies, and report where a version stands (progress, blocked, stale, mismatches). Discovers each board's fields on first use and saves them to a config file, so it works with any owner, field names or workflow. Use it whenever the user plans a version or sprint, creates or triages tickets/issues, moves a card, asks "where are we on vX", or starts a branch, opens a PR or merges one in a repo that has a board config (.github/board.json) - even if they never mention the board.
compatibility: gh CLI (logged in, with the "project" scope), Python 3.8+ (standard library only), git.
---

# GitHub project board

This skill keeps a GitHub Projects (v2) board in step with the work, the way a team uses
a Jira board: versions are planned into tickets, tickets move across columns as branches
and PRs happen, and anyone can ask where a version stands.

Everything goes through the `gh` CLI. What gh can do on its own (`gh issue create`,
`gh issue edit`, `gh pr ...`, `gh api`) is called directly; what it can't do comfortably
(field/option IDs, setting several fields, sub-issues, dependencies, the report) goes
through the bundled helper `scripts/board.py`. No MCP server is involved.

Nothing about the board is assumed. Field names, option names and the meaning of each
column differ from board to board, so they are discovered once and stored in a config
file; after that, later runs need no lookups.

## Ground truth and the words used here

- **Issues are the source of truth; the board is a view of them.** If the board and the
  issue disagree, the issue (open/closed, merged PR) wins, but say so rather than
  silently fixing it (see Rules).
- **Status roles.** The skill reasons in five roles - `not_started`, `ready`,
  `in_progress`, `in_review`, `done` - and the config maps each to the board's own
  option names (a board might call them Todo / Todo / In Progress / Review / Shipped).
  Always speak to the user in *their* option names ("moved #42 to Review"), never in role
  names. Any role may be unmapped; skip steps that need it.
- **Done** means merged, or explicitly accepted by the user. Never move a ticket to the
  done option because the code was written, a PR was opened or tests passed locally.
- **Version** = a milestone (named by the configured pattern, default `vX.Y.Z`) plus,
  unless the config says `"tracking_issues": false`, one tracking issue labelled
  `tracking` (configurable) whose sub-issues are the version's tickets. The tracking
  issue exists so GitHub's sub-issue progress bar shows how far along the version is.

## Step 0 - find the config

Run from the repo root. The helper finds the config at `$BOARD_CONFIG`, or by walking up
from the current directory to `.github/board.json`; pass `--config PATH` if the user keeps
it elsewhere (and remember that path for the rest of the session). No config → do
**Setup** first, then continue
with what the user asked. Config present → read it (it is small) so you know the field
names, option names and role mapping before you write anything.

## Setup (first run in a repo)

1. **Which board?** Ask for the project URL (`https://github.com/orgs/<org>/projects/<n>`
   or `https://github.com/users/<user>/projects/<n>`), or owner + number. You don't need
   to ask whether the owner is a user or an organization - discovery finds out.
2. **Discover** (read-only):
   ```bash
   python <skill-dir>/scripts/board.py discover --url <project-url>
   ```
   It prints the project ID, every field with its type and options, and a `suggested`
   mapping guessed from the names.
3. **Ask the user to confirm the mapping**, showing it in their words, e.g.:
   > Status field: **Status**. Not started → **Todo**, ready → **Todo**, in progress →
   > **In Progress**, in review → **Review**, done → **Shipped**.
   > Priority field: **Priority** (High / Medium / Low). Size field: *none found*.
   > Config file: `.github/board.json` - OK, or somewhere else?

   Any role or field may be absent. A role can map to several options (`A|B`).
4. **Write the config**:
   ```bash
   python <skill-dir>/scripts/board.py init --url <project-url> --repo <owner/name> \
     --status-field Status --role not_started=Todo --role ready=Todo \
     --role in_progress="In Progress" --role in_review=Review --role done=Shipped \
     --priority-field Priority   # --size-field <name> if there is one
   # optional: --no-tracking  --tracking-label <name>  --milestone-pattern <pattern>
   #           --stale-days <n>  --config <path>
   ```
   The file holds the project node ID, each field's ID and option IDs, the role mapping
   and the version settings - see `references/config.md` for the schema. Suggest the
   user commits it; it contains IDs, not secrets.
5. **Missing scope.** If gh answers with a scope error (helper exit code 4), tell the user
   to run `gh auth refresh -s project` themselves - it opens a browser login - and
   continue afterwards.

**When an ID is rejected** (exit code 3, "Could not resolve to a node", or an option
the config doesn't know): run `board.py refresh`, which re-discovers IDs while keeping
the mapping, then retry the step once. If a mapped option no longer exists, ask the user
how to remap it.

## The helper

`python <skill-dir>/scripts/board.py [--config PATH] [--dry-run] <command> ...`

| Command | What it does |
|---|---|
| `discover --url U` | fields/options + suggested mapping (read-only) |
| `init ...` / `refresh` | write / re-discover the config |
| `add ISSUE... [--status S] [--priority P] [--size Z]` | add to board and set fields, one call per issue |
| `move ISSUE... --to S` | set status; adds the issue to the board if it isn't there |
| `sub PARENT CHILD...` | link sub-issues (addSubIssue) |
| `block ISSUE --by BLOCKER...` | record dependencies (addBlockedBy) |
| `milestone TITLE [--due YYYY-MM-DD]` | create the milestone only if missing |
| `issue-id ISSUE` | print an issue's node ID |
| `report [--milestone M] [--stale-days N] [--json]` | version status report |

`ISSUE` can be `42`, `#42`, `owner/repo#42`, an issue URL or a node ID. Status `S` can be
a role (`in_progress`) or an option name (`"In Progress"`, case-insensitive) - prefer the
role so the same command works on any board. Every write is idempotent (adding an item
that is already on the board returns the existing item; re-linking a sub-issue or
dependency is reported as "already linked"), so re-running a step is safe.

`--dry-run` prints each write as a runnable `gh api graphql` command instead of sending
it. Reads still run if gh can reach GitHub; when they can't, the helper prints
`<PLACEHOLDER>`s and carries on. `--shell powershell` switches the quoting for Windows.

If the helper can't run at all, `references/graphql.md` has the raw queries and
mutations to use with `gh api graphql`.

## Planning a version

Input: a version name and a list of tickets, in whatever shape the user gives it.

1. **Check the repo's own conventions first**: labels in use (`gh label list`), issue
   templates in `.github/ISSUE_TEMPLATE/`, CONTRIBUTING.md, CLAUDE.md. Use the repo's
   type labels (bug / feature / chore / ...) if it has them.
2. **Preview, don't create.** Show one table and stop for confirmation:

   | # | Title | Type | Priority | Size | Status | Blocked by |
   |---|---|---|---|---|---|---|
   | 1 | Add CSV export | feature | High | – | Todo | – |
   | 2 | CSV import | feature | Medium | – | Todo | 1 |

   - Use the board's option names; leave a column out if the board has no such field
     (say so once, e.g. "this board has no Size field").
   - New tickets start in the `not_started` option unless the user says otherwise.
   - Fill gaps with sensible guesses and mark them as guesses; ask about anything you
     really can't infer.
   - **Flag tickets that look like two tickets** - "X and Y", two verbs, two areas of the
     code, or a title that only makes sense as a list - and propose the split. Don't
     split without a yes.
   - List what will be created: milestone (or "already exists"), tracking issue, N issues,
     labels that don't exist yet.
3. **After the user confirms**, create in this order (dependencies need numbers that only
   exist after creation):
   1. Missing labels: `gh label create <name>` (only those absent from `gh label list`).
   2. Milestone: `board.py milestone <version> [--due YYYY-MM-DD]`.
   3. Tracking issue (skip in no-tracking mode):
      `gh issue create --title "<version>" --label tracking --milestone <version> --body-file <file>`
      using `assets/tracking-body.md`.
   4. One issue per ticket, as a sub-issue of the tracking issue:
      `gh issue create --title ... --label <type> --milestone <version> --parent <tracking#> --body-file <file>`
      using `assets/issue-body.md` (Why / Tasks / Done when). Write each body to a temp
      file - always `--body-file`, never `--body`, because inline bodies break on
      backticks, `#` and quotes, especially on Windows.
   5. Board fields for all of them, tracking issue included:
      `board.py add <n>... --status not_started --priority <P>` (group issues that share
      the same values into one call).
   6. Dependencies: `board.py block <n> --by <m>`.
   7. Update the tracking issue's body so it lists every ticket of the version, the new
      ones included (`gh issue edit <tracking#> --body-file <file>`, built from the current
      body so nothing is lost). Do this whenever tickets join an existing version too.
   8. Finish with the **status report** for the new version and the board URL.

   If a step fails midway, report what was created (numbers and links) before
   retrying, so nothing gets created twice.

## Lifecycle: branch → PR → merge

When you start a branch, open a PR or merge one in a repo with a board config, update
the ticket as part of the same task, without being asked. Find the ticket from the
branch name (`42-csv-export`, `feat/42-...`), the PR body (`Closes #42`), or by
searching open issues in the current milestone; if it's still ambiguous, ask.

| Event | Board | Also |
|---|---|---|
| Branch started for #N | `board.py move N --to in_progress` | assign the user if unassigned: `gh issue edit N --add-assignee @me` |
| PR opened for #N | `board.py move N --to in_review` | PR body links the issue: `Closes #N`, or `Refs #N` if the PR is partial work |
| PR merged | `board.py move N --to done` | check the issue closed; if it was `Refs`, leave it open and ask about the remaining work |

- Move to done **explicitly** even when `Closes #N` and the board's built-in workflows
  may already have done it - the call is idempotent and those workflows are often off.
- If the repo has its own branching, versioning, commit or PR conventions (a skill,
  CONTRIBUTING.md, `.github/pull_request_template.md`), follow them rather than
  inventing or restating your own. If the PR template already has a `Closes #` line,
  fill that line in rather than adding a second one.
- If the PR is already open and its body lacks the link, add it with
  `gh pr edit <pr> --body-file <file>`, built from the current body
  (`gh pr view <pr> --json body -q .body`) so nothing the user wrote is lost.
- A PR that is not tied to a ticket isn't an error; mention it once and move on.

## Status report

```bash
python <skill-dir>/scripts/board.py report [--milestone v2.1.0] [--stale-days 7]
```

One paginated GraphQL query over the board reads each item's fields by name
(`fieldValueByName`), plus one small query of the repo's milestones to catch issues that
never made it onto the board. With no `--milestone`, it covers every open milestone with
items on the board. For each version it gives:

- progress from the tracking issue's sub-issue counts (or from the milestone's
  open/closed counts in no-tracking mode),
- tickets per status, and a ticket table,
- **blocked**: open tickets with an open "blocked by" dependency or a `blocked` label,
- **stale**: tickets in the in-progress or in-review options with no update for N days,
- **mismatches**: closed but not done; done but still open,
- **disagreements** between milestone, tracking sub-issues and board.

Present it to the user in a few lines first - progress, what's blocked, what needs a
decision - then the details. Don't fix mismatches or disagreements on your own: say what
you'd do ("move #12 to Shipped since its PR merged?") and wait, because each fix could
be the wrong one (a closed-as-not-planned ticket shouldn't be "Shipped").

Single-issue edits (title, labels, priority, assignee) are plain `gh issue edit` plus
`board.py add <n> --priority ...` for board fields.

## Rules

- **Confirm before anything destructive or wide**: closing, deleting, transferring or
  reopening issues; removing items from the board; closing milestones; or editing more
  than one existing issue at once (bulk relabel, bulk move). Show what will change and
  wait. Moving the single ticket the user is currently working on through its lifecycle
  needs no confirmation. Creating the issues of a confirmed plan is covered by that
  confirmation.
- **No secrets or personal data in issues on public repos** (tokens, internal URLs,
  customer names, emails, logs that contain them). Check visibility with
  `gh repo view --json visibility`. If the repo has its own privacy rule (CLAUDE.md,
  CONTRIBUTING.md), follow it - it may be stricter.
- **Done is merged or accepted** - see above.
- **When the milestone, the sub-issues and the board disagree, report and ask** rather
  than picking one. Typical cases: a sub-issue of the v2.1.0 tracking issue sits in
  milestone v2.2.0; an issue is in the milestone but not on the board; a ticket is
  Shipped on the board but its issue is open.

## When gh can't run (dry runs)

If the user says gh isn't available, or asks for a dry run, do the whole procedure
without sending anything: show the preview table, then every command in order - plain
`gh` commands as you'd run them, and helper writes as `board.py --dry-run ...` output
(runnable `gh api graphql` commands). IDs and issue numbers that only exist after
creation become placeholders that say where they come from, e.g. `<#tracking>`,
`<#csv-export>`, `<ITEM_ID acme/widget#42>`. When there's no config to read, write the
config you would create and use `<PROJECT_ID>`, `<STATUS_FIELD_ID>`, `<OPT Review>` etc.
in place of discovered IDs.

## Reference files

- `references/config.md` - config schema and an example; read when writing or fixing
  a config by hand, or when the user asks what it stores.
- `references/graphql.md` - raw GraphQL for every helper write and the report query;
  read when the helper can't be used or a GitHub error needs decoding.
- `assets/issue-body.md`, `assets/tracking-body.md` - issue body templates.
