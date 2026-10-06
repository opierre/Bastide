#!/usr/bin/env python3
"""Render the pipeline overview into the `ci-ok` job summary.

Reads `toJSON(needs)` from the NEEDS environment variable. Each stage is a
reusable workflow whose outputs carry one result per inner job (see
ci-lint.yml and friends), which gives one row per job. A stage that failed
before publishing its outputs falls back to a single row with the stage's own
result.

Never decides anything: ci-ok's own step gates the build. The exit code is
always 0.

Runs on the runner's system Python; standard library only.
"""

from __future__ import annotations

import json
import os
import sys

from summary_md import ICON, callout, plural, table, write

RESULTS = {"success", "failure", "cancelled", "skipped"}
STATUS = {"success": "pass", "failure": "fail", "cancelled": "warn", "skipped": "skip"}
LABEL = {
    "success": "Passed",
    "failure": "Failed",
    "cancelled": "Cancelled",
    "skipped": "Skipped (no changes)",
}

# Plumbing jobs, shown only when they break.
HIDDEN = {"changes"}


def rows_of(needs: dict) -> list[tuple[str, str, str]]:
    """(stage, job, result) for every job, in pipeline order."""
    rows = []
    for stage, need in needs.items():
        result = need.get("result") or "?"
        outputs = {k: v for k, v in (need.get("outputs") or {}).items() if v in RESULTS}
        if outputs:
            rows += [(stage, job, job_result) for job, job_result in outputs.items()]
        elif stage not in HIDDEN or result != "success":
            rows.append((stage, "—", result))
    return rows


def main() -> int:
    try:
        needs = json.loads(os.environ.get("NEEDS") or "{}")
    except json.JSONDecodeError as exc:
        write(callout("warn", f"Could not read the job results: {exc}"))
        return 0

    rows = rows_of(needs)
    failed = [
        f"{stage.title()} / {job}"
        for stage, job, result in rows
        if result in ("failure", "cancelled")
    ]
    passed = sum(1 for r in rows if r[2] == "success")
    skipped = sum(1 for r in rows if r[2] == "skipped")

    if failed:
        lines = callout(
            "fail", f"**{plural(len(failed), 'job')} failed:** {', '.join(failed)}."
        )
    else:
        verdict = f"**All green.** {plural(passed, 'job')} passed"
        if skipped:
            verdict += (
                f", {skipped} skipped because their side of the repo did not change"
            )
        lines = callout("pass", verdict + ".")

    lines += table(
        ["", "Stage", "Job", "Result"],
        [
            [
                ICON.get(STATUS.get(result, "warn"), "❔"),
                f"**{stage.title()}**",
                job.replace("-", " "),
                LABEL.get(result, result),
            ]
            for stage, job, result in rows
        ],
        limit=None,
    )
    write(lines)
    return 0


if __name__ == "__main__":
    sys.exit(main())
