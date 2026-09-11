#!/usr/bin/env python3
"""Render lint and test reports into the GitHub Actions job summary.

ruff, ty, pytest and `flutter test` all gate the build on their own exit code;
none of them leaves anything readable behind once the log scrolls past. This
script turns their machine-readable reports into markdown tables on the run
page, so a red job says what broke without opening the raw log, and a green
non-blocking job still shows the backlog it is tolerating.

  --ruff          ruff --output-format=json
  --ty-junit      ty check --output-format=junit
  --pytest-junit  pytest --junitxml
  --dart-json     flutter test --file-reporter=json:<path>

Every input is optional, and a missing or unparsable report is noted inline
rather than raised: this script never decides whether the build passes, so it
must never be the reason a job fails. The exit code is always 0.

Runs on the runner's system Python; standard library only.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# The tables are a summary, not the report - the artifact holds every row.
MAX_ROWS = 25


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


def table(headers: list[str], rows: list[list[str]]) -> list[str]:
    """Render rows as a markdown table, truncated to MAX_ROWS."""
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join("---" for _ in headers) + " |",
    ]
    for row in rows[:MAX_ROWS]:
        lines.append("| " + " | ".join(row) + " |")
    lines.append("")
    if len(rows) > MAX_ROWS:
        hidden = len(rows) - MAX_ROWS
        lines.append(f"_...and {hidden} more; the full report is in the job artifact._")
        lines.append("")
    return lines


def section(title: str, path: Path, parse) -> list[str]:
    """Run one parser, turning any failure into a visible note instead of a crash."""
    lines = [f"## {title}", ""]
    if not path.exists():
        lines += [f"_No report at `{path.name}` - the step did not run._", ""]
        return lines
    try:
        lines += parse(path)
    except Exception as exc:  # noqa: BLE001 - a broken report must not fail the job
        lines += [f"_Could not read `{path.name}`: {exc.__class__.__name__}: {exc}_", ""]
    return lines


def ruff(path: Path) -> list[str]:
    diagnostics = json.loads(path.read_text(encoding="utf-8") or "[]")
    if not diagnostics:
        return ["No lint violations. :white_check_mark:", ""]

    by_rule: dict[str, int] = {}
    rows: list[list[str]] = []
    for diagnostic in diagnostics:
        # `code` is null for syntax errors, which have no rule to name.
        code = diagnostic.get("code") or "syntax"
        by_rule[code] = by_rule.get(code, 0) + 1
        location = diagnostic.get("location") or {}
        url = diagnostic.get("url")
        rows.append(
            [
                f"[{code}]({url})" if url else code,
                f"`{relative(diagnostic.get('filename', '?'))}:{location.get('row', '?')}`",
                clean(diagnostic.get("message", "")),
            ]
        )

    counts = ", ".join(
        f"`{code}` x{n}" for code, n in sorted(by_rule.items(), key=lambda kv: -kv[1])
    )
    return [f"**{len(diagnostics)} violations** - {counts}", ""] + table(
        ["Rule", "Location", "Message"], rows
    )


def junit_cases(path: Path):
    """Yield (suite name, testcase) for both <testsuites> and bare <testsuite> roots."""
    root = ET.parse(path).getroot()
    suites = root.iter("testsuite") if root.tag == "testsuites" else [root]
    for suite in suites:
        for case in suite.iter("testcase"):
            yield suite.get("name", "?"), case


def ty_junit(path: Path) -> list[str]:
    by_rule: dict[str, int] = {}
    rows: list[list[str]] = []
    for suite_name, case in junit_cases(path):
        failure = case.find("failure")
        if failure is None:
            continue
        # ty encodes the rule in the testcase name, e.g. `org.ty.invalid-argument-type`.
        rule = case.get("name", "?").removeprefix("org.ty.")
        by_rule[rule] = by_rule.get(rule, 0) + 1
        rows.append(
            [
                rule,
                f"`{relative(suite_name)}:{case.get('line', '?')}`",
                clean(failure.get("message", "")),
            ]
        )

    if not rows:
        return ["No type errors. :white_check_mark:", ""]

    counts = ", ".join(
        f"`{rule}` x{n}" for rule, n in sorted(by_rule.items(), key=lambda kv: -kv[1])
    )
    return [
        f"**{len(rows)} diagnostics** - {counts}",
        "",
        "> `ty check` is not blocking yet, so these do not fail the build. See CI-PLAN.md.",
        "",
    ] + table(["Rule", "Location", "Message"], rows)


def pytest_junit(path: Path) -> list[str]:
    passed = failed = skipped = 0
    duration = 0.0
    rows: list[list[str]] = []
    for _suite_name, case in junit_cases(path):
        duration += float(case.get("time") or 0.0)
        outcome = case.find("failure")
        kind = "failure"
        if outcome is None:
            outcome = case.find("error")
            kind = "error"
        if outcome is None:
            if case.find("skipped") is not None:
                skipped += 1
            else:
                passed += 1
            continue
        failed += 1
        name = f"{case.get('classname', '')}::{case.get('name', '?')}".lstrip(":")
        rows.append([kind, f"`{name}`", clean(outcome.get("message", ""))])

    total = passed + failed + skipped
    headline = (
        f"**{passed} passed**, {failed} failed, {skipped} skipped "
        f"of {total} in {duration:.1f}s"
    )
    if not rows:
        return [f"{headline} :white_check_mark:", ""]
    return [headline, ""] + table(["Kind", "Test", "Message"], rows)


def dart_json(path: Path) -> list[str]:
    """Parse the dart test JSON reporter's newline-delimited event stream."""
    suites: dict[int, str] = {}
    tests: dict[int, dict] = {}
    passed = failed = skipped = 0
    rows: list[list[str]] = []

    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            # The reporter interleaves the odd non-JSON line from the tool itself.
            continue

        kind = event.get("type")
        if kind == "suite":
            suite = event.get("suite") or {}
            suites[suite.get("id")] = suite.get("path") or "?"
        elif kind == "testStart":
            test = event.get("test") or {}
            tests[test.get("id")] = test
        elif kind == "testDone":
            # `hidden` marks the synthetic loading/tearDown tests, not real cases.
            if event.get("hidden"):
                continue
            if event.get("skipped"):
                skipped += 1
            elif event.get("result") == "success":
                passed += 1
            else:
                failed += 1
                test = tests.get(event.get("testID"), {})
                suite_path = suites.get(test.get("suiteID"), "?")
                rows.append(
                    [
                        clean(test.get("name", "?")),
                        f"`{relative(suite_path)}:{test.get('line', '?')}`",
                    ]
                )

    total = passed + failed + skipped
    headline = f"**{passed} passed**, {failed} failed, {skipped} skipped of {total}"
    if not rows:
        return [f"{headline} :white_check_mark:", ""]
    return [headline, ""] + table(["Test", "Location"], rows)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--title", default="Report", help="heading for this job's block")
    parser.add_argument("--ruff", type=Path, help="ruff --output-format=json report")
    parser.add_argument("--ty-junit", type=Path, help="ty check --output-format=junit report")
    parser.add_argument("--pytest-junit", type=Path, help="pytest --junitxml report")
    parser.add_argument("--dart-json", type=Path, help="flutter test --file-reporter=json report")
    args = parser.parse_args()

    lines = [f"# {args.title}", ""]
    if args.ruff:
        lines += section("ruff", args.ruff, ruff)
    if args.ty_junit:
        lines += section("ty", args.ty_junit, ty_junit)
    if args.pytest_junit:
        lines += section("pytest", args.pytest_junit, pytest_junit)
    if args.dart_json:
        lines += section("flutter test", args.dart_json, dart_json)

    text = "\n".join(lines)
    print(text)
    step_summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if step_summary:
        with open(step_summary, "a", encoding="utf-8") as fh:
            fh.write(text + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
