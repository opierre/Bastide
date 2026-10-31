# Raw GraphQL (for when the helper can't be used)

All of these run with `gh api graphql -f query='...' -f var=value` (strings) or
`-F var=123` (numbers). Pass values as variables rather than pasting them into the
query: it avoids quoting problems, especially in PowerShell. Reads need the
`read:project` scope, writes the `project` scope (`gh auth refresh -s project`).

## Discover a board's fields

Works for users and organizations alike.

```graphql
query($login:String!, $number:Int!) {
  repositoryOwner(login:$login) {
    __typename
    ... on User { projectV2(number:$number) { ...P } }
    ... on Organization { projectV2(number:$number) { ...P } }
  }
}
fragment P on ProjectV2 {
  id title url
  fields(first:50) { nodes {
    ... on ProjectV2FieldCommon { id name dataType }
    ... on ProjectV2SingleSelectField { options { id name } }
  } }
}
```

## Issue node ID

```bash
gh issue view 42 --repo acme/widget --json id -q .id
```

## Add to board (idempotent: returns the existing item if already there)

```graphql
mutation($p:ID!, $c:ID!) {
  addProjectV2ItemById(input:{projectId:$p, contentId:$c}) { item { id } }
}
```

## Set a field

```graphql
mutation($p:ID!, $i:ID!, $f:ID!, $v:String!) {
  updateProjectV2ItemFieldValue(input:{projectId:$p, itemId:$i, fieldId:$f,
    value:{singleSelectOptionId:$v}}) { projectV2Item { id } }
}
```

For a number field use `$v:Float!` and `value:{number:$v}`; for text, `value:{text:$v}`.

gh alternative (gh 2.100+), by name, no IDs needed:
`gh project item-edit --url <issue-url> --field Status --value "In Progress"`.

## Sub-issues and dependencies

```graphql
mutation($i:ID!, $s:ID!) { addSubIssue(input:{issueId:$i, subIssueId:$s}) { issue { number } } }
mutation($i:ID!, $b:ID!) { addBlockedBy(input:{issueId:$i, blockingIssueId:$b}) { issue { number } } }
```

`$i` is the parent / the blocked issue; `$s` the child; `$b` the blocker. New issues can
get a parent at creation with `gh issue create --parent <number|url>`.

## Milestones (no gh command)

```bash
gh api "repos/acme/widget/milestones?state=all&per_page=100" --jq '.[] | [.number,.title,.state] | @tsv'
gh api repos/acme/widget/milestones -X POST -f title=v2.1.0 -f due_on=2026-12-01T23:59:59Z
```

## Report query (one page; repeat with `$c` = `endCursor` while `hasNextPage`)

```graphql
query($p:ID!, $c:String, $statusF:String!, $priorityF:String!) {
  node(id:$p) { ... on ProjectV2 {
    items(first:100, after:$c) {
      pageInfo { hasNextPage endCursor }
      nodes {
        id updatedAt isArchived
        status: fieldValueByName(name:$statusF) { ... on ProjectV2ItemFieldSingleSelectValue { name } }
        priority: fieldValueByName(name:$priorityF) { ... on ProjectV2ItemFieldSingleSelectValue { name } }
        content { __typename ... on Issue {
          number title state stateReason updatedAt
          milestone { title } labels(first:20) { nodes { name } }
          parent { number }
          subIssuesSummary { total completed percentCompleted }
          blockedBy(first:20) { nodes { number state } }
        } }
      }
    }
  } }
}
```

## Common errors

| Message | Meaning |
|---|---|
| `INSUFFICIENT_SCOPES`, "requires read:project" | `gh auth refresh -s project` |
| "Could not resolve to a node with the global id" | stale ID in the config → `board.py refresh` |
| "The single select option Id does not belong to the field" | option was renamed/recreated → `refresh` |
| "Issue may not contain duplicate sub-issues" | already linked - fine |
| "Sub issue may only have one parent" | it already has another parent: report and ask before moving it |
