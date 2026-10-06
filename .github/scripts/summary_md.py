"""Markdown building blocks shared by the job-summary scripts.

GitHub renders job summaries as GitHub Flavored Markdown, alerts included, so
every summary follows one shape: a status callout that says the verdict in a
sentence, a compact table of checks, and the detail rows folded underneath.

Standard library only; imported by sibling scripts run as `python3 <path>`.
"""

from __future__ import annotations

import os

# The tables are a summary, not the report - the artifact holds every row.
MAX_ROWS = 25

# Alert flavour per verdict. TIP renders green, CAUTION red, WARNING amber.
ALERT = {"pass": "TIP", "fail": "CAUTION", "warn": "WARNING", "info": "NOTE"}
ICON = {"pass": "✅", "fail": "❌", "warn": "⚠️", "info": "ℹ️", "skip": "⏭️"}


def relative(path: str) -> str:
    """Shorten an absolute runner path to something repo-relative."""
    workspace = os.environ.get("GITHUB_WORKSPACE")
    normalised = path.replace("\\", "/")
    if workspace:
        prefix = workspace.replace("\\", "/").rstrip("/") + "/"
        if normalised.startswith(prefix):
            return normalised[len(prefix) :]
    return normalised


def clean(text: str) -> str:
    """Make a tool message safe for a single markdown table cell."""
    return " ".join(str(text).split()).replace("|", "\\|")[:200]


def callout(kind: str, *lines: str) -> list[str]:
    """A GitHub alert block; `kind` is a key of ALERT, each line its own paragraph."""
    body: list[str] = []
    for line in lines:
        body += [">", f"> {line}"] if body else [f"> {line}"]
    return [f"> [!{ALERT[kind]}]", *body, ""]


def table(
    headers: list[str], rows: list[list[str]], *, limit: int | None = MAX_ROWS
) -> list[str]:
    """Render rows as a markdown table, truncated to `limit` rows."""
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join("---" for _ in headers) + " |",
    ]
    shown = rows if limit is None else rows[:limit]
    for row in shown:
        lines.append("| " + " | ".join(row) + " |")
    lines.append("")
    if len(rows) > len(shown):
        hidden = len(rows) - len(shown)
        lines += [
            f"<sub>…and {hidden} more; the full report is in the job artifact.</sub>",
            "",
        ]
    return lines


def details(summary: str, body: list[str], *, open_: bool = False) -> list[str]:
    """Fold `body` under a clickable summary line."""
    # The blank line after <summary> is what makes GitHub render the body as markdown.
    return [
        f"<details{' open' if open_ else ''}><summary>{summary}</summary>",
        "",
        *body,
        "</details>",
        "",
    ]


def counts(by_key: dict[str, int]) -> str:
    """`F401` ×3, `E501` ×1 - most frequent first."""
    return ", ".join(
        f"`{key}` ×{n}" for key, n in sorted(by_key.items(), key=lambda kv: -kv[1])
    )


def plural(n: int, word: str, many: str | None = None) -> str:
    return f"{n} {word}" if n == 1 else f"{n} {many or word + 's'}"


def write(lines: list[str]) -> None:
    """Print the summary and append it to the job summary when on Actions."""
    text = "\n".join(lines)
    print(text)
    step_summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if step_summary:
        with open(step_summary, "a", encoding="utf-8") as fh:
            fh.write(text + "\n")
