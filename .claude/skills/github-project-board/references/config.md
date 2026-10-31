# Board config

Written by `board.py init`, updated by `board.py refresh`. Default location
`.github/board.json`; any path works if passed with `--config` or `$BOARD_CONFIG`.
It holds IDs and names only - no tokens - so it is safe to commit.

## Example (fictional acme/widget board)

```json
{
  "version": 1,
  "repo": "acme/widget",
  "project": {
    "owner": "acme",
    "owner_type": "Organization",
    "number": 4,
    "id": "PVT_kwDOAbc123",
    "title": "Widget",
    "url": "https://github.com/orgs/acme/projects/4",
    "closed": false
  },
  "fields": {
    "status": {
      "name": "Status", "id": "PVTSSF_lADOAbc123zg1", "type": "SINGLE_SELECT",
      "options": {"Todo": "f75ad846", "In Progress": "47fc9ee4", "Review": "a1b2c3d4", "Shipped": "98236657"}
    },
    "priority": {
      "name": "Priority", "id": "PVTSSF_lADOAbc123zg2", "type": "SINGLE_SELECT",
      "options": {"High": "0a1b2c3d", "Medium": "1b2c3d4e", "Low": "2c3d4e5f"}
    },
    "size": null
  },
  "status_roles": {
    "not_started": "Todo",
    "ready": "Todo",
    "in_progress": "In Progress",
    "in_review": "Review",
    "done": "Shipped"
  },
  "versions": {
    "milestone_pattern": "vX.Y.Z",
    "tracking_issues": true,
    "tracking_label": "tracking"
  },
  "stale_days": 7
}
```

## Keys

| Key | Meaning |
|---|---|
| `repo` | `owner/name` where tickets are created; bare issue numbers resolve here |
| `project.id` | project node ID (`PVT_...`), used by every board write |
| `fields.<role>` | `status`, `priority`, `size`; `null` when the board has no such field. `type` is the GitHub dataType: `SINGLE_SELECT`, `NUMBER` or `TEXT` can be written; `ITERATION` is read-only here |
| `fields.<role>.options` | option name → option ID (single-select only) |
| `status_roles` | role → option name, or a list of names when several options mean the same thing (e.g. `"done": ["Shipped", "Released"]`; the first one is used for writes). A missing role means that step is skipped |
| `versions.milestone_pattern` | how version milestones are named; `vX.Y.Z` by default, could be `Sprint N`, `2026-Q4`, ... |
| `versions.tracking_issues` | `false` = milestone-only versions, no tracking issue |
| `versions.tracking_label` | label that marks tracking issues |
| `stale_days` | report threshold for stale tickets |

Extra keys you add (for example `"type_labels": ["bug", "feature", "chore"]`) are kept
by `refresh`.
