#!/usr/bin/env python3
"""board.py - GitHub Projects (v2) helper for the github-project-board skill.

Standard library only. Every GitHub call goes through the `gh` CLI
(`gh api graphql` / `gh api`), so it uses whatever account gh is logged in as.

It covers what gh has no direct command for:
  discover   read a board's fields/options (read-only) and suggest a role mapping
  init       discover + write the config file with the role mapping you choose
  refresh    re-discover IDs for an existing config (after an ID is rejected)
  add        add issues to the board and set status/priority/size in one call
  move       set the status of one or more issues (adds them to the board if needed)
  sub        link sub-issues to a parent (addSubIssue)
  block      record "blocked by" dependencies (addBlockedBy)
  milestone  create a milestone if it does not exist yet
  issue-id   print an issue's node ID
  report     version status report (one paginated GraphQL query over the board)

Global flags (before the command):
  --config PATH   config file (default: $BOARD_CONFIG, else .github/board.json
                  found by walking up from the current directory)
  --dry-run       print every write as a runnable `gh` command instead of sending it.
                  Reads still run when gh is available; if a read fails, a
                  <PLACEHOLDER> is used so the rest of the plan can still print.
  --shell posix|powershell   quoting style for --dry-run output (default: by OS)

Exit codes: 0 ok, 1 GitHub/gh error, 2 usage or config error,
            3 an ID was rejected (run `refresh`), 4 gh lacks the project scope.
"""

import argparse
import datetime as dt
import json
import os
import re
import shlex
import shutil
import subprocess
import sys

DEFAULT_CONFIG = os.path.join(".github", "board.json")
STATUS_ROLES = ["not_started", "ready", "in_progress", "in_review", "done"]
ROLE_HINTS = {
    "not_started": ["backlog", "todo", "to do", "new", "triage", "not started", "icebox"],
    "ready": ["ready", "todo", "to do", "selected", "next", "up next"],
    "in_progress": ["in progress", "progress", "doing", "wip", "active", "started", "dev"],
    "in_review": ["review", "in review", "qa", "testing", "verify", "pr"],
    "done": ["done", "shipped", "closed", "complete", "completed", "released", "merged", "finished"],
}
FIELD_HINTS = {
    "status": ["status", "state", "stage", "column"],
    "priority": ["priority", "prio", "urgency", "importance"],
    "size": ["size", "estimate", "points", "story points", "effort", "complexity"],
}

DRY = False
SHELL = "powershell" if os.name == "nt" else "posix"


class BoardError(Exception):
    def __init__(self, msg, code=1):
        super().__init__(msg)
        self.code = code


# --------------------------------------------------------------------------- gh plumbing

def _compact(q):
    return re.sub(r"\s+", " ", q).strip()


def _quote(arg):
    if SHELL == "powershell":
        return "'" + arg.replace("'", "''") + "'" if re.search(r"[^\w@%+=:,./-]", arg) else arg
    return shlex.quote(arg)


def shell_join(args):
    return " ".join(_quote(a) for a in args)


def is_placeholder(v):
    return isinstance(v, str) and v.startswith("<") and v.endswith(">")


def _classify(stderr):
    s = stderr or ""
    if "INSUFFICIENT_SCOPES" in s or "read:project" in s or "scope" in s and "project" in s:
        return BoardError(
            "gh is missing the 'project' scope. Run:  gh auth refresh -s project\n" + s.strip(), 4)
    if "Could not resolve to a node" in s or "NOT_FOUND" in s and ("PVT" in s or "node" in s):
        return BoardError(
            "GitHub rejected a stored ID (the board or a field may have changed). "
            "Run `board.py refresh` and retry.\n" + s.strip(), 3)
    return BoardError(s.strip() or "gh failed", 1)


def run_gh(args, write=False, label=None):
    """Run gh. For writes in dry-run mode, print the command and return None."""
    if write and DRY:
        if label:
            print(f"# {label}")
        print(shell_join(["gh"] + args))
        print()
        return None
    if not shutil.which("gh"):
        raise BoardError("gh CLI not found on PATH", 1)
    p = subprocess.run(["gh"] + args, capture_output=True, text=True, encoding="utf-8")
    if p.returncode != 0:
        raise _classify(p.stderr + p.stdout)
    return p.stdout


def graphql(query, variables=None, write=False, label=None):
    args = ["api", "graphql", "-f", "query=" + _compact(query)]
    for k, v in (variables or {}).items():
        if v is None:
            continue
        if isinstance(v, bool):
            args += ["-F", f"{k}={'true' if v else 'false'}"]
        elif isinstance(v, (int, float)):
            args += ["-F", f"{k}={v}"]
        else:
            args += ["-f", f"{k}={v}"]
    out = run_gh(args, write=write, label=label)
    if out is None:
        return None
    data = json.loads(out)
    if data.get("errors"):
        raise _classify(json.dumps(data["errors"]))
    return data["data"]


def read_or_placeholder(fn, placeholder):
    """Run a read; in dry-run mode fall back to a placeholder if it fails."""
    try:
        return fn()
    except BoardError as e:
        if DRY and e.code != 2:
            print(f"# note: read failed, using {placeholder} ({str(e).splitlines()[0][:100]})", file=sys.stderr)
            return placeholder
        raise


# --------------------------------------------------------------------------- config

def find_config(path=None):
    if path:
        return path
    if os.environ.get("BOARD_CONFIG"):
        return os.environ["BOARD_CONFIG"]
    d = os.getcwd()
    while True:
        cand = os.path.join(d, DEFAULT_CONFIG)
        if os.path.exists(cand):
            return cand
        parent = os.path.dirname(d)
        if parent == d:
            return DEFAULT_CONFIG
        d = parent


def load_config(path):
    if not os.path.exists(path):
        raise BoardError(f"No board config at {path}. Run `board.py discover` then `board.py init` first.", 2)
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save_config(path, cfg):
    if DRY:
        print(f"# would write config to {path}:")
        print(json.dumps(cfg, indent=2))
        return
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    print(f"wrote {path}")


# --------------------------------------------------------------------------- discovery

PROJECT_QUERY = """
query($login:String!, $number:Int!) {
  repositoryOwner(login:$login) {
    __typename
    ... on User { projectV2(number:$number) { ...P } }
    ... on Organization { projectV2(number:$number) { ...P } }
  }
}
fragment P on ProjectV2 {
  id title url closed
  fields(first:50) { nodes {
    __typename
    ... on ProjectV2FieldCommon { id name dataType }
    ... on ProjectV2SingleSelectField { options { id name } }
    ... on ProjectV2IterationField { configuration { iterations { id title startDate } } }
  } }
}
"""


def parse_project_url(url):
    m = re.search(r"github\.com/(orgs|users)/([^/]+)/projects/(\d+)", url or "")
    if not m:
        raise BoardError(f"Not a project URL: {url} (expected https://github.com/orgs|users/<owner>/projects/<n>)", 2)
    return m.group(2), int(m.group(3))


def discover(owner, number):
    data = graphql(PROJECT_QUERY, {"login": owner, "number": number})
    ro = data.get("repositoryOwner") if data else None
    if not ro:
        raise BoardError(f"No user or organization named {owner!r}", 2)
    proj = ro.get("projectV2")
    if not proj:
        raise BoardError(f"{ro['__typename']} {owner} has no project #{number} visible to this gh login", 2)
    fields = []
    for n in proj["fields"]["nodes"]:
        if not n or "id" not in n:
            continue
        f = {"name": n["name"], "id": n["id"], "type": n["dataType"]}
        if n.get("options") is not None:
            f["options"] = {o["name"]: o["id"] for o in n["options"]}
        fields.append(f)
    return {
        "owner": owner, "owner_type": ro["__typename"], "number": number,
        "id": proj["id"], "title": proj["title"], "url": proj["url"], "closed": proj["closed"],
    }, fields


def _match(name, hints):
    n = name.lower().strip()
    return any(n == h or h in n for h in hints)


def suggest(fields):
    sugg = {"fields": {}, "status_roles": {}}
    usable = [f for f in fields if f["type"] in ("SINGLE_SELECT", "NUMBER", "TEXT", "ITERATION")]
    for role, hints in FIELD_HINTS.items():
        cands = [f for f in usable if _match(f["name"], hints)]
        if role == "status":
            cands = [f for f in cands if f["type"] == "SINGLE_SELECT"]
        sugg["fields"][role] = cands[0]["name"] if cands else None
    st = next((f for f in fields if f["name"] == sugg["fields"]["status"]), None)
    if st:
        opts = list(st["options"])
        for role in STATUS_ROLES:
            hit = next((o for o in opts if o.lower() in ROLE_HINTS[role]), None) or \
                next((o for o in opts if any(h in o.lower() for h in ROLE_HINTS[role])), None)
            sugg["status_roles"][role] = hit
        # Common shape: first column is "not started", the next unclaimed one is "ready".
        if not sugg["status_roles"]["not_started"] and opts:
            sugg["status_roles"]["not_started"] = opts[0]
        if not sugg["status_roles"]["ready"]:
            sugg["status_roles"]["ready"] = sugg["status_roles"]["not_started"]
    return sugg


def cmd_discover(a):
    owner, number = (parse_project_url(a.url) if a.url else (a.owner, a.number))
    if not owner or not number:
        raise BoardError("give --url or --owner and --number", 2)
    proj, fields = discover(owner, number)
    print(json.dumps({"project": proj, "fields": fields, "suggested": suggest(fields)}, indent=2))


def _parse_roles(pairs):
    roles = {}
    for p in pairs or []:
        if "=" not in p:
            raise BoardError(f"--role expects role=Option, got {p!r}", 2)
        k, v = p.split("=", 1)
        k = k.strip()
        if k not in STATUS_ROLES:
            raise BoardError(f"unknown status role {k!r}; roles are {', '.join(STATUS_ROLES)}", 2)
        vals = [x.strip() for x in v.split("|") if x.strip()]
        roles[k] = vals[0] if len(vals) == 1 else vals
    return roles


def build_config(proj, fields, repo, field_names, roles, versions, stale_days, extra=None):
    by_name = {f["name"].lower(): f for f in fields}
    out_fields = {}
    for role in ("status", "priority", "size"):
        name = field_names.get(role)
        if not name:
            out_fields[role] = None
            continue
        f = by_name.get(name.lower())
        if not f:
            raise BoardError(f"board has no field named {name!r}. Fields: {', '.join(x['name'] for x in fields)}", 2)
        out_fields[role] = f
    st = out_fields.get("status")
    if st:
        if st["type"] != "SINGLE_SELECT":
            raise BoardError("the status field must be a single-select field", 2)
        opts = {o.lower(): o for o in st["options"]}
        for role, val in list(roles.items()):
            vals = val if isinstance(val, list) else [val]
            fixed = []
            for v in vals:
                if v.lower() not in opts:
                    raise BoardError(f"status option {v!r} not in {list(st['options'])}", 2)
                fixed.append(opts[v.lower()])
            roles[role] = fixed[0] if len(fixed) == 1 else fixed
        if "done" not in roles:
            raise BoardError("map at least the 'done' role (--role done=<Option>)", 2)
    cfg = {
        "version": 1,
        "repo": repo,
        "project": proj,
        "fields": out_fields,
        "status_roles": roles,
        "versions": versions,
        "stale_days": stale_days,
    }
    if extra:
        cfg.update(extra)
    return cfg


def cmd_init(a):
    path = find_config(a.config)
    if os.path.exists(path) and not a.force and not DRY:
        raise BoardError(f"{path} exists; use --force to overwrite or `refresh` to update IDs", 2)
    owner, number = (parse_project_url(a.url) if a.url else (a.owner, a.number))
    if not owner or not number:
        raise BoardError("give --url or --owner and --number", 2)
    proj, fields = discover(owner, number)
    repo = a.repo or current_repo()
    versions = {
        "milestone_pattern": a.milestone_pattern,
        "tracking_issues": not a.no_tracking,
        "tracking_label": a.tracking_label,
    }
    cfg = build_config(proj, fields, repo,
                       {"status": a.status_field, "priority": a.priority_field, "size": a.size_field},
                       _parse_roles(a.role), versions, a.stale_days)
    save_config(path, cfg)


def cmd_refresh(a):
    path = find_config(a.config)
    cfg = load_config(path)
    p = cfg["project"]
    proj, fields = discover(p["owner"], p["number"])
    names = {r: (f or {}).get("name") for r, f in cfg["fields"].items()}
    roles = cfg.get("status_roles", {})
    extra = {k: v for k, v in cfg.items()
             if k not in ("version", "repo", "project", "fields", "status_roles", "versions", "stale_days")}
    new = build_config(proj, fields, cfg.get("repo"), names, dict(roles), cfg.get("versions", {}),
                       cfg.get("stale_days", 7), extra)
    save_config(path, new)


def current_repo():
    try:
        out = run_gh(["repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"])
        return out.strip()
    except BoardError:
        return None


# --------------------------------------------------------------------------- issues

ISSUE_RE = re.compile(r"^(?:https://github\.com/)?([\w.-]+)/([\w.-]+)(?:/issues/|/pull/|#)(\d+)$")


def parse_issue(ref, default_repo):
    ref = str(ref).strip()
    if is_placeholder(ref) or re.match(r"^(I_|PR_)\w+$", ref):
        inner = ref.strip("<>")
        node = f"<ISSUE_ID {inner}>" if inner.startswith("#") else ref   # <#csv-export> = a future issue number
        return {"node": node, "repo": default_repo, "number": None, "label": inner}
    m = ISSUE_RE.match(ref)
    if m:
        return {"node": None, "repo": f"{m.group(1)}/{m.group(2)}", "number": int(m.group(3)),
                "label": f"{m.group(1)}/{m.group(2)}#{m.group(3)}"}
    m = re.match(r"^#?(\d+)$", ref)
    if m:
        if not default_repo:
            raise BoardError(f"issue {ref}: no repo (set 'repo' in the config or pass owner/repo#N)", 2)
        return {"node": None, "repo": default_repo, "number": int(m.group(1)),
                "label": f"{default_repo}#{m.group(1)}"}
    raise BoardError(f"can't parse issue reference {ref!r}", 2)


def issue_node(ref, default_repo):
    it = parse_issue(ref, default_repo)
    if it["node"]:
        return it
    owner, name = it["repo"].split("/")

    def fetch():
        d = graphql("query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){issueOrPullRequest(number:$n){"
                    "... on Issue{id} ... on PullRequest{id}}}}", {"o": owner, "r": name, "n": it["number"]})
        node = (d.get("repository") or {}).get("issueOrPullRequest")
        if not node:
            raise BoardError(f"{it['label']} not found", 2)
        return node["id"]

    it["node"] = read_or_placeholder(fetch, f"<ISSUE_ID {it['label']}>")
    return it


def add_item(cfg, it):
    d = graphql("mutation($p:ID!,$c:ID!){addProjectV2ItemById(input:{projectId:$p,contentId:$c}){item{id}}}",
                {"p": cfg["project"]["id"], "c": it["node"]}, write=True,
                label=f"add {it['label']} to board (idempotent: returns the existing item if already there)")
    if d is None:
        return f"<ITEM_ID {it['label']}>"
    return d["addProjectV2ItemById"]["item"]["id"]


def resolve_value(cfg, role, value):
    """Return (field, graphql value object, display) for a role (status/priority/size) or field name."""
    field = cfg["fields"].get(role)
    if field is None:
        raise BoardError(f"this board has no {role} field configured; skip it", 2)
    if role == "status" and value in cfg.get("status_roles", {}):
        mapped = cfg["status_roles"][value]
        value = mapped[0] if isinstance(mapped, list) else mapped
    t = field["type"]
    if t == "SINGLE_SELECT":
        opts = {k.lower(): (k, v) for k, v in field["options"].items()}
        hit = opts.get(str(value).lower())
        if not hit:
            raise BoardError(f"{field['name']} has no option {value!r} (options: {', '.join(field['options'])}). "
                             "If it was just added on GitHub, run `board.py refresh`.", 2)
        return field, {"singleSelectOptionId": hit[1]}, hit[0]
    if t == "NUMBER":
        return field, {"number": float(value)}, value
    if t == "TEXT":
        return field, {"text": str(value)}, value
    raise BoardError(f"field type {t} is not supported for writes", 2)


def set_field(cfg, item_id, it, role, value):
    field, val, shown = resolve_value(cfg, role, value)
    vtype, vname = next(iter(val.items()))
    gtype = {"singleSelectOptionId": "String", "number": "Float", "text": "String"}[vtype]
    q = (f"mutation($p:ID!,$i:ID!,$f:ID!,$v:{gtype}!){{updateProjectV2ItemFieldValue(input:{{projectId:$p,"
         f"itemId:$i,fieldId:$f,value:{{{vtype}:$v}}}}){{projectV2Item{{id}}}}}}")
    graphql(q, {"p": cfg["project"]["id"], "i": item_id, "f": field["id"], "v": vname},
            write=True, label=f"{it['label']}: {field['name']} = {shown}")
    return shown


def cmd_add(a, status_only=None):
    cfg = load_config(find_config(a.config))
    results = []
    status = status_only if status_only is not None else a.status
    wanted = [(r, v) for r, v in (("status", status), ("priority", getattr(a, "priority", None)),
                                    ("size", getattr(a, "size", None))) if v is not None]
    for role, val in wanted:          # validate names before touching GitHub
        resolve_value(cfg, role, val)
    for ref in a.issues:
        it = issue_node(ref, cfg.get("repo"))
        item = add_item(cfg, it)
        done = {"issue": it["label"], "item": item}
        for role, val in wanted:
            done[role] = set_field(cfg, item, it, role, val)
        results.append(done)
    if not DRY:
        print(json.dumps(results, indent=2))


def cmd_move(a):
    a.priority = a.size = None
    cmd_add(a, status_only=a.status)


def _idempotent_write(q, variables, label, ok_patterns):
    try:
        graphql(q, variables, write=True, label=label)
        return "linked"
    except BoardError as e:
        if any(p in str(e).lower() for p in ok_patterns):
            return "already linked"
        raise


def cmd_sub(a):
    cfg = load_config(find_config(a.config)) if os.path.exists(find_config(a.config)) else {}
    repo = a.repo or cfg.get("repo")
    parent = issue_node(a.parent, repo)
    for ref in a.children:
        child = issue_node(ref, repo)
        r = _idempotent_write(
            "mutation($i:ID!,$s:ID!){addSubIssue(input:{issueId:$i,subIssueId:$s}){issue{number}}}",
            {"i": parent["node"], "s": child["node"]},
            f"{child['label']} becomes a sub-issue of {parent['label']}",
            ["duplicate sub-issue", "already", "may only have one parent"])
        if not DRY:
            print(f"{child['label']} -> {parent['label']}: {r}")


def cmd_block(a):
    cfg = load_config(find_config(a.config)) if os.path.exists(find_config(a.config)) else {}
    repo = a.repo or cfg.get("repo")
    issue = issue_node(a.issue, repo)
    for ref in a.by:
        blocker = issue_node(ref, repo)
        r = _idempotent_write(
            "mutation($i:ID!,$b:ID!){addBlockedBy(input:{issueId:$i,blockingIssueId:$b}){issue{number}}}",
            {"i": issue["node"], "b": blocker["node"]},
            f"{issue['label']} is blocked by {blocker['label']}",
            ["already", "duplicate"])
        if not DRY:
            print(f"{issue['label']} blocked by {blocker['label']}: {r}")


def cmd_issue_id(a):
    cfg = load_config(find_config(a.config)) if os.path.exists(find_config(a.config)) else {}
    print(issue_node(a.issue, a.repo or cfg.get("repo"))["node"])


def cmd_milestone(a):
    cfg = load_config(find_config(a.config)) if os.path.exists(find_config(a.config)) else {}
    repo = a.repo or cfg.get("repo") or current_repo()
    if not repo:
        raise BoardError("no repo: pass --repo owner/name", 2)

    def fetch():
        out = run_gh(["api", "--paginate", "--slurp", f"repos/{repo}/milestones?state=all&per_page=100"])
        return [m for page in json.loads(out) for m in page] if out.strip() else []

    existing = read_or_placeholder(fetch, None)
    if existing:
        hit = next((m for m in existing if m["title"] == a.title), None)
        if hit:
            print(json.dumps({"milestone": a.title, "number": hit["number"], "state": hit["state"],
                              "created": False}))
            return
    args = ["api", f"repos/{repo}/milestones", "-X", "POST", "-f", f"title={a.title}"]
    if a.due:
        args += ["-f", f"due_on={a.due}T23:59:59Z" if len(a.due) == 10 else f"due_on={a.due}"]
    if a.description:
        args += ["-f", f"description={a.description}"]
    out = run_gh(args, write=True, label=f"create milestone {a.title} (only if missing)")
    if out:
        m = json.loads(out)
        print(json.dumps({"milestone": a.title, "number": m["number"], "state": m["state"], "created": True}))


# --------------------------------------------------------------------------- report

VALUE_FRAG = """... on ProjectV2ItemFieldSingleSelectValue{name}
 ... on ProjectV2ItemFieldNumberValue{number}
 ... on ProjectV2ItemFieldTextValue{text}
 ... on ProjectV2ItemFieldIterationValue{title}"""


def report_query(cfg):
    aliases, var_decl = [], []
    for role in ("status", "priority", "size"):
        f = cfg["fields"].get(role)
        if f:
            aliases.append(f"{role}: fieldValueByName(name:${role}F){{ {VALUE_FRAG} }}")
            var_decl.append(f"${role}F:String!")
    return f"""
query($p:ID!, $c:String {''.join(', ' + v for v in var_decl)}) {{
  node(id:$p) {{ ... on ProjectV2 {{ title url
    items(first:100, after:$c) {{
      pageInfo {{ hasNextPage endCursor }}
      nodes {{
        id updatedAt isArchived
        {' '.join(aliases)}
        content {{
          __typename
          ... on Issue {{
            id number title url state stateReason closedAt updatedAt
            repository {{ nameWithOwner }}
            milestone {{ title state dueOn }}
            labels(first:20) {{ nodes {{ name }} }}
            assignees(first:5) {{ nodes {{ login }} }}
            parent {{ number repository {{ nameWithOwner }} }}
            subIssuesSummary {{ total completed percentCompleted }}
            subIssues(first:50) {{ nodes {{ number state repository {{ nameWithOwner }} }} }}
            blockedBy(first:20) {{ nodes {{ number title state repository {{ nameWithOwner }} }} }}
          }}
          ... on PullRequest {{ number title url state merged updatedAt repository {{ nameWithOwner }} }}
          ... on DraftIssue {{ title updatedAt }}
        }}
      }}
    }}
  }} }}
}}"""


MILESTONE_QUERY = """
query($o:String!, $r:String!) { repository(owner:$o, name:$r) {
  milestones(first:100, states:[OPEN, CLOSED], orderBy:{field:CREATED_AT, direction:DESC}) { nodes {
    title state dueOn
    issues(first:100) { totalCount nodes { number state } }
  } }
} }"""


def fetch_report_data(cfg, milestone_check=True):
    q = report_query(cfg)
    items, cursor = [], None
    variables = {"p": cfg["project"]["id"]}
    for role in ("status", "priority", "size"):
        if cfg["fields"].get(role):
            variables[f"{role}F"] = cfg["fields"][role]["name"]
    while True:
        variables["c"] = cursor
        d = graphql(q, variables)
        page = d["node"]["items"]
        items += page["nodes"]
        if not page["pageInfo"]["hasNextPage"]:
            break
        cursor = page["pageInfo"]["endCursor"]
    milestones = []
    if milestone_check and cfg.get("repo"):
        o, r = cfg["repo"].split("/")
        milestones = graphql(MILESTONE_QUERY, {"o": o, "r": r})["repository"]["milestones"]["nodes"]
    return {"board_url": cfg["project"].get("url"), "items": items, "milestones": milestones}


def _val(v):
    if not v:
        return None
    for k in ("name", "number", "text", "title"):
        if k in v and v[k] is not None:
            return v[k]
    return None


def _ts(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00")) if s else None


def _role_options(cfg, role):
    v = cfg.get("status_roles", {}).get(role)
    if v is None:
        return set()
    return set(v if isinstance(v, list) else [v])


def build_report(cfg, data, milestones_filter=None, stale_days=None, now=None):
    now = now or dt.datetime.now(dt.timezone.utc)
    stale_days = stale_days if stale_days is not None else cfg.get("stale_days", 7)
    vcfg = cfg.get("versions", {})
    tlabel = vcfg.get("tracking_label", "tracking")
    use_tracking = vcfg.get("tracking_issues", True)
    done_opts = _role_options(cfg, "done")
    active_opts = _role_options(cfg, "in_progress") | _role_options(cfg, "in_review")
    status_order = list((cfg["fields"].get("status") or {}).get("options", {}))
    repo = cfg.get("repo")

    issues = []
    for n in data["items"]:
        c = n.get("content") or {}
        if n.get("isArchived") or c.get("__typename") != "Issue":
            continue
        labels = [x["name"] for x in c["labels"]["nodes"]]
        upd = max(filter(None, [_ts(n.get("updatedAt")), _ts(c.get("updatedAt"))]))
        issues.append({
            "number": c["number"], "repo": c["repository"]["nameWithOwner"], "title": c["title"],
            "url": c["url"], "state": c["state"], "stateReason": c.get("stateReason"),
            "milestone": (c.get("milestone") or {}).get("title"),
            "due": (c.get("milestone") or {}).get("dueOn"),
            "labels": labels, "tracking": tlabel in labels,
            "status": _val(n.get("status")), "priority": _val(n.get("priority")), "size": _val(n.get("size")),
            "updated": upd, "subSummary": c.get("subIssuesSummary"),
            "subs": [(s["repository"]["nameWithOwner"], s["number"], s["state"]) for s in c["subIssues"]["nodes"]],
            "parent": c.get("parent"),
            "blockedBy": [b for b in c["blockedBy"]["nodes"] if b["state"] == "OPEN"],
        })

    def ref(i):
        return f"#{i['number']}" if i["repo"] == repo else f"{i['repo']}#{i['number']}"

    ms_info = {m["title"]: m for m in data.get("milestones", [])}
    titles = sorted({i["milestone"] for i in issues if i["milestone"]})
    if milestones_filter:
        titles = [t for t in milestones_filter]
    else:
        titles = [t for t in titles if (ms_info.get(t, {}).get("state", "OPEN") == "OPEN")]

    out = {"board_url": data.get("board_url"), "generated": now.isoformat(timespec="minutes"),
           "stale_days": stale_days, "versions": [],
           "columns": [r for r in ("priority", "size") if cfg["fields"].get(r)]}
    for t in titles:
        mine = [i for i in issues if i["milestone"] == t]
        trackers = [i for i in mine if i["tracking"]]
        tickets = [i for i in mine if not i["tracking"]]
        v = {"milestone": t, "due": (ms_info.get(t) or {}).get("dueOn") or next((i["due"] for i in mine if i["due"]), None),
             "tracking": [ref(x) for x in trackers], "progress": None,
             "counts": {}, "tickets": [], "blocked": [], "stale": [], "mismatches": [], "disagreements": []}
        if use_tracking and len(trackers) == 1:
            s = trackers[0]["subSummary"] or {}
            v["progress"] = {"source": f"tracking {ref(trackers[0])}", "done": s.get("completed", 0),
                             "total": s.get("total", 0), "pct": s.get("percentCompleted", 0)}
        elif t in ms_info:
            nodes = ms_info[t]["issues"]["nodes"]
            real = [x for x in nodes if not any(tr["number"] == x["number"] for tr in trackers)]
            closed = sum(1 for x in real if x["state"] == "CLOSED")
            v["progress"] = {"source": "milestone", "done": closed, "total": len(real),
                             "pct": round(100 * closed / len(real)) if real else 0}
        if use_tracking and not trackers:
            v["disagreements"].append(f"no issue labelled '{tlabel}' in {t}")
        if len(trackers) > 1:
            v["disagreements"].append(f"several tracking issues in {t}: {', '.join(ref(x) for x in trackers)}")

        for i in tickets:
            st = i["status"] or "(no status)"
            v["counts"][st] = v["counts"].get(st, 0) + 1
            v["tickets"].append({"ref": ref(i), "title": i["title"], "status": st, "priority": i["priority"],
                                 "size": i["size"], "state": i["state"]})
            if i["state"] == "OPEN" and (i["blockedBy"] or "blocked" in [l.lower() for l in i["labels"]]):
                why = ", ".join(f"#{b['number']}" if b["repository"]["nameWithOwner"] == repo
                                else f"{b['repository']['nameWithOwner']}#{b['number']}" for b in i["blockedBy"])
                v["blocked"].append(f"{ref(i)} {i['title']} — " + (f"blocked by {why} (open)" if why else "labelled blocked"))
            if i["state"] == "OPEN" and i["status"] in active_opts:
                age = (now - i["updated"]).days
                if age >= stale_days:
                    v["stale"].append(f"{ref(i)} {i['title']} — {i['status']}, no update for {age} days")
            if i["state"] == "CLOSED" and i["status"] not in done_opts:
                reason = " (closed as not planned)" if i["stateReason"] == "NOT_PLANNED" else ""
                v["mismatches"].append(f"{ref(i)} {i['title']} — closed{reason} but status is {st}")
            if i["state"] == "OPEN" and i["status"] in done_opts:
                v["mismatches"].append(f"{ref(i)} {i['title']} — status {st} but issue still open")

        if use_tracking and len(trackers) == 1:
            tr = trackers[0]
            sub_keys = {(r, n) for r, n, _ in tr["subs"]}
            ticket_keys = {(i["repo"], i["number"]) for i in tickets}
            for r, n, _ in tr["subs"]:
                if (r, n) not in ticket_keys:
                    other = next((i for i in issues if (i["repo"], i["number"]) == (r, n)), None)
                    where = (f"milestone {other['milestone']}" if other and other["milestone"] else "no milestone") \
                        if other else "not on the board"
                    v["disagreements"].append(f"#{n} is a sub-issue of {ref(tr)} but is in {where}")
            for i in tickets:
                if (i["repo"], i["number"]) not in sub_keys:
                    v["disagreements"].append(f"{ref(i)} is in {t} but not a sub-issue of {ref(tr)}")
        if t in ms_info:
            on_board = {i["number"] for i in mine if i["repo"] == repo}
            for x in ms_info[t]["issues"]["nodes"]:
                if x["number"] not in on_board:
                    v["disagreements"].append(f"#{x['number']} is in milestone {t} but not on the board")
        order = {s: k for k, s in enumerate(status_order)}
        v["counts"] = dict(sorted(v["counts"].items(), key=lambda kv: order.get(kv[0], 99)))
        v["tickets"].sort(key=lambda x: (order.get(x["status"], 99), x["ref"]))
        out["versions"].append(v)
    return out


def render_report(r):
    lines = []
    for v in r["versions"]:
        due = f" (due {v['due'][:10]})" if v.get("due") else ""
        lines.append(f"## {v['milestone']}{due}")
        p = v["progress"]
        if p:
            lines.append(f"Progress: {p['done']}/{p['total']} done ({p['pct']}%) — from {p['source']}")
        lines.append("Status: " + (" · ".join(f"{k} {n}" for k, n in v["counts"].items()) or "no tickets"))
        lines.append("")
        if v["tickets"]:
            cols = r.get("columns", ["priority", "size"])
            lines.append("| Ticket | Title | Status |" + "".join(f" {c.title()} |" for c in cols))
            lines.append("|---|---|---|" + "---|" * len(cols))
            for t in v["tickets"]:
                lines.append(f"| {t['ref']} | {t['title']} | {t['status']} |"
                             + "".join(f" {t[c] if t[c] is not None else '–'} |" for c in cols))
            lines.append("")
        for key, head in (("blocked", "Blocked"), ("stale", f"Stale (no update for {r['stale_days']}+ days)"),
                          ("mismatches", "Mismatches (issue state vs board status)"),
                          ("disagreements", "Milestone / sub-issues / board disagree")):
            if v[key]:
                lines.append(f"**{head}** ({len(v[key])})")
                lines += [f"- {x}" for x in v[key]]
                lines.append("")
    if not r["versions"]:
        lines.append("No open milestones with items on the board.")
    if r.get("board_url"):
        lines.append(f"Board: {r['board_url']}")
    return "\n".join(lines).rstrip() + "\n"


def cmd_report(a):
    cfg = load_config(find_config(a.config))
    if a.input:
        with open(a.input, encoding="utf-8") as f:
            data = json.load(f)
    else:
        data = fetch_report_data(cfg, milestone_check=not a.no_milestone_check)
    if a.save_raw:
        with open(a.save_raw, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
    now = _ts(a.now) if a.now else None
    r = build_report(cfg, data, a.milestone, a.stale_days, now)
    print(json.dumps(r, indent=2, default=str) if a.json else render_report(r), end="")


# --------------------------------------------------------------------------- CLI

def main(argv=None):
    global DRY, SHELL
    # Titles and the report use non-ASCII characters; a Windows console defaults to cp1252.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except (AttributeError, ValueError):
            pass
    ap = argparse.ArgumentParser(prog="board.py", description=__doc__.split("\n\n")[0])
    ap.add_argument("--config")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--shell", choices=["posix", "powershell"])
    sp = ap.add_subparsers(dest="cmd", required=True)

    p = sp.add_parser("discover", help="list the board's fields/options and suggest a mapping (read-only)")
    p.add_argument("--url"); p.add_argument("--owner"); p.add_argument("--number", type=int)
    p.set_defaults(fn=cmd_discover)

    p = sp.add_parser("init", help="discover and write the config")
    p.add_argument("--url"); p.add_argument("--owner"); p.add_argument("--number", type=int)
    p.add_argument("--repo", help="owner/name of the repo the tickets live in (default: current repo)")
    p.add_argument("--status-field"); p.add_argument("--priority-field"); p.add_argument("--size-field")
    p.add_argument("--role", action="append",
                   help="status role mapping, e.g. --role in_progress='In Progress' (use A|B for several options)")
    p.add_argument("--milestone-pattern", default="vX.Y.Z")
    p.add_argument("--tracking-label", default="tracking")
    p.add_argument("--no-tracking", action="store_true", help="milestone-only versions, no tracking issues")
    p.add_argument("--stale-days", type=int, default=7)
    p.add_argument("--force", action="store_true")
    p.set_defaults(fn=cmd_init)

    p = sp.add_parser("refresh", help="re-discover IDs for the existing config")
    p.set_defaults(fn=cmd_refresh)

    p = sp.add_parser("add", help="add issues to the board and set fields")
    p.add_argument("issues", nargs="+", help="42, #42, owner/repo#42, an issue URL, or a node ID")
    p.add_argument("--status", help="a status role (in_progress...) or an option name")
    p.add_argument("--priority"); p.add_argument("--size")
    p.set_defaults(fn=cmd_add)

    p = sp.add_parser("move", help="set status (adds to the board if needed)")
    p.add_argument("issues", nargs="+")
    p.add_argument("--to", dest="status", required=True, help="a status role or option name")
    p.set_defaults(fn=cmd_move)

    p = sp.add_parser("sub", help="link sub-issues to a parent")
    p.add_argument("parent"); p.add_argument("children", nargs="+"); p.add_argument("--repo")
    p.set_defaults(fn=cmd_sub)

    p = sp.add_parser("block", help="record that ISSUE is blocked by others")
    p.add_argument("issue"); p.add_argument("--by", nargs="+", required=True); p.add_argument("--repo")
    p.set_defaults(fn=cmd_block)

    p = sp.add_parser("milestone", help="create a milestone if missing")
    p.add_argument("title"); p.add_argument("--due", help="YYYY-MM-DD"); p.add_argument("--description")
    p.add_argument("--repo")
    p.set_defaults(fn=cmd_milestone)

    p = sp.add_parser("issue-id", help="print an issue's node ID")
    p.add_argument("issue"); p.add_argument("--repo")
    p.set_defaults(fn=cmd_issue_id)

    p = sp.add_parser("report", help="version status report")
    p.add_argument("--milestone", action="append", help="limit to these milestones (repeatable)")
    p.add_argument("--stale-days", type=int)
    p.add_argument("--json", action="store_true", help="machine-readable output")
    p.add_argument("--input", help="build the report from a file saved with --save-raw instead of calling GitHub")
    p.add_argument("--save-raw", help="also save the raw fetched data to this file")
    p.add_argument("--no-milestone-check", action="store_true",
                   help="skip the extra query that finds milestone issues missing from the board")
    p.add_argument("--now", help=argparse.SUPPRESS)
    p.set_defaults(fn=cmd_report)

    a = ap.parse_args(argv)
    DRY = a.dry_run
    if a.shell:
        SHELL = a.shell
    try:
        a.fn(a)
    except BoardError as e:
        print(f"error: {e}", file=sys.stderr)
        return e.code
    return 0


if __name__ == "__main__":
    sys.exit(main())
