#!/usr/bin/env python3
"""Render lint, test and scan reports into the GitHub Actions job summary.

ruff, ty, pytest, flutter and gitleaks all gate the build on their own exit
code; none of them leaves anything readable behind once the log scrolls past.
This script turns their reports into one summary per job: a callout with the
verdict, a table with one row per check, and the findings folded underneath,
so a red job says what broke without opening the raw log.

  --ruff              ruff check --output-format=json
  --ruff-format-log   ruff format --check output
  --ty-junit          ty check --output-format=junit
  --pytest-junit      pytest --junitxml
  --analyze-log       flutter analyze output
  --dart-format-log   dart format --set-exit-if-changed output
  --dart-json         flutter test --file-reporter=json:<path>
  --coverage-xml      pytest --cov-report=xml       (informational, never red)
  --lcov              flutter test --coverage       (informational, never red)
  --gitleaks          gitleaks --report-format=json

Every input is optional, and a missing or unparsable report is noted inline
rather than raised: this script never decides whether the build passes, so it
must never be the reason a job fails. The exit code is always 0.

Runs on the runner's system Python; standard library only.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from collections.abc import Callable, Iterator
from dataclasses import dataclass, field
from pathlib import Path

from summary_md import (
    ICON,
    callout,
    clean,
    counts,
    details,
    plural,
    relative,
    table,
    write,
)


@dataclass
class Check:
    """One tool's verdict: `result` fills the table cell, `detail` the fold."""

    name: str
    status: str  # pass | fail | warn | measure (a number, not a verdict)
    result: str
    detail: list[str] = field(default_factory=list)
    note: str = ""  # one line for the callout when the check did not pass


def run(name: str, path: Path, parse: Callable[[str, Path], Check]) -> Check:
    """Run one parser, turning any failure into a visible note instead of a crash."""
    if not path.exists():
        return Check(
            name,
            "warn",
            "No report",
            note=f"**{name}** did not run; no report at `{path.name}`.",
        )
    try:
        return parse(name, path)
    except Exception as exc:  # noqa: BLE001 - a broken report must not fail the job
        reason = f"{exc.__class__.__name__}: {exc}"
        return Check(
            name,
            "warn",
            "Unreadable report",
            note=f"**{name}** report could not be read ({clean(reason)}).",
        )


def lines_of(path: Path) -> Iterator[str]:
    # Tool logs may carry ANSI colour even when piped.
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        yield re.sub(r"\x1b\[[0-9;]*m", "", line).rstrip()


# --- lint ---------------------------------------------------------------------


def ruff(name: str, path: Path) -> Check:
    diagnostics = json.loads(path.read_text(encoding="utf-8") or "[]")
    if not diagnostics:
        return Check(name, "pass", "No violations")

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
                f"[`{code}`]({url})" if url else f"`{code}`",
                f"`{relative(diagnostic.get('filename', '?'))}:{location.get('row', '?')}`",
                clean(diagnostic.get("message", "")),
            ]
        )
    found = plural(len(diagnostics), "violation")
    return Check(
        name,
        "fail",
        found,
        details(
            f"{found}: {counts(by_rule)}",
            table(["Rule", "Location", "Message"], rows),
            open_=True,
        ),
        note=f"**{name}** found {found}.",
    )


def ruff_format(name: str, path: Path) -> Check:
    files = [
        line.removeprefix("Would reformat: ")
        for line in lines_of(path)
        if line.startswith("Would reformat: ")
    ]
    return formatter(name, files, "uv run ruff format")


def dart_format(name: str, path: Path) -> Check:
    files = [
        line.removeprefix("Changed ")
        for line in lines_of(path)
        if line.startswith("Changed ")
    ]
    return formatter(name, files, "dart format lib test")


def formatter(name: str, files: list[str], fix: str) -> Check:
    if not files:
        return Check(name, "pass", "Formatted")
    found = plural(len(files), "file")
    rows = [[f"`{relative(f)}`"] for f in files]
    return Check(
        name,
        "fail",
        f"{found} to reformat",
        details(f"{found} to reformat", table(["File"], rows), open_=True),
        note=f"**{name}**: {found} to reformat. Run `{fix}` and commit.",
    )


def junit_cases(path: Path) -> Iterator[tuple[str, ET.Element]]:
    """Yield (suite name, testcase) for both <testsuites> and bare <testsuite> roots."""
    root = ET.parse(path).getroot()
    suites = root.iter("testsuite") if root.tag == "testsuites" else [root]
    for suite in suites:
        for case in suite.iter("testcase"):
            yield suite.get("name", "?"), case


def ty_junit(name: str, path: Path) -> Check:
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
                f"`{rule}`",
                f"`{relative(suite_name)}:{case.get('line', '?')}`",
                clean(failure.get("message", "")),
            ]
        )
    if not rows:
        return Check(name, "pass", "No type errors")
    found = plural(len(rows), "diagnostic")
    return Check(
        name,
        "fail",
        found,
        details(
            f"{found}: {counts(by_rule)}",
            table(["Rule", "Location", "Message"], rows),
            open_=True,
        ),
        note=f"**{name}** reported {found}.",
    )


# `  error • Message • lib/x.dart:3:7 • rule_name` - `•` on Linux, `-` on Windows.
ANALYZE_LINE = re.compile(
    r"^\s*(?P<severity>error|warning|info)\s+[•-]\s+(?P<message>.+)\s+[•-]\s+"
    r"(?P<file>\S+):(?P<line>\d+):\d+\s+[•-]\s+(?P<rule>\S+)\s*$"
)


def flutter_analyze(name: str, path: Path) -> Check:
    by_rule: dict[str, int] = {}
    rows: list[list[str]] = []
    for line in lines_of(path):
        match = ANALYZE_LINE.match(line)
        if not match:
            continue
        rule = match["rule"]
        by_rule[rule] = by_rule.get(rule, 0) + 1
        rows.append(
            [
                match["severity"],
                f"`{rule}`",
                f"`{relative(match['file'])}:{match['line']}`",
                clean(match["message"]),
            ]
        )
    if not rows:
        return Check(name, "pass", "No issues")
    found = plural(len(rows), "issue")
    return Check(
        name,
        "fail",
        found,
        details(
            f"{found}: {counts(by_rule)}",
            table(["Severity", "Rule", "Location", "Message"], rows),
            open_=True,
        ),
        note=f"**{name}** found {found}.",
    )


# --- test ---------------------------------------------------------------------


def tally(passed: int, failed: int, skipped: int, seconds: float | None = None) -> str:
    parts = [f"{passed} passed"]
    if failed:
        parts.append(f"{failed} failed")
    if skipped:
        parts.append(f"{skipped} skipped")
    if seconds is not None:
        parts.append(f"{seconds:.1f}s")
    return " · ".join(parts)


def pytest_junit(name: str, path: Path) -> Check:
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
        test = f"{case.get('classname', '')}::{case.get('name', '?')}".lstrip(":")
        rows.append([kind, f"`{test}`", clean(outcome.get("message", ""))])

    result = tally(passed, failed, skipped, duration)
    if not rows:
        return Check(name, "pass", result)
    return Check(
        name,
        "fail",
        result,
        details(
            f"{plural(failed, 'failing test')}",
            table(["Kind", "Test", "Message"], rows),
            open_=True,
        ),
        note=f"**{name}**: {plural(failed, 'test')} failed out of {passed + failed + skipped}.",
    )


def dart_json(name: str, path: Path) -> Check:
    """Parse the dart test JSON reporter's newline-delimited event stream."""
    suites: dict[object, str] = {}
    tests: dict[object, dict] = {}
    passed = failed = skipped = 0
    started = finished = None
    rows: list[list[str]] = []

    for line in lines_of(path):
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            # The reporter interleaves the odd non-JSON line from the tool itself.
            continue

        kind = event.get("type")
        if kind == "start":
            started = event.get("time")
        elif kind == "done":
            finished = event.get("time")
        elif kind == "suite":
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

    # Event times are milliseconds since the run started.
    seconds = (finished - (started or 0)) / 1000 if finished is not None else None
    result = tally(passed, failed, skipped, seconds)
    if not rows:
        return Check(name, "pass", result)
    return Check(
        name,
        "fail",
        result,
        details(
            f"{plural(failed, 'failing test')}",
            table(["Test", "Location"], rows),
            open_=True,
        ),
        note=f"**{name}**: {plural(failed, 'test')} failed out of {passed + failed + skipped}.",
    )


# --- coverage -----------------------------------------------------------------

# How many of the least covered files the fold lists.
COVERAGE_ROWS = 10

# `flutter gen-l10n` output: thousands of generated lines no test is meant to drive.
LCOV_GENERATED = ("lib/l10n/",)


def percent(covered: int, total: int) -> str:
    return f"{100 * covered / total:.1f}%" if total else "n/a"


def coverage(name: str, files: list[tuple[str, int, int]], extra: str = "") -> Check:
    """Shared rendering for (file, covered lines, total lines) rows."""
    covered = sum(c for _, c, _ in files)
    total = sum(t for _, _, t in files)
    result = f"**{percent(covered, total)}** of lines ({covered:,} / {total:,}){extra}"
    gaps = sorted((f for f in files if f[1] < f[2]), key=lambda f: (f[1] / f[2], -f[2]))
    rows = [[f"`{path}`", percent(c, t), f"{t - c:,}"] for path, c, t in gaps]
    detail = (
        details(
            f"Least covered files ({min(len(rows), COVERAGE_ROWS)} of {len(rows)} not fully covered)",
            table(["File", "Lines", "Missed"], rows, limit=COVERAGE_ROWS),
        )
        if rows
        else []
    )
    return Check(name, "measure", result, detail)


def cobertura(name: str, path: Path) -> Check:
    """coverage.py's XML report (pytest --cov-report=xml)."""
    root = ET.parse(path).getroot()
    files: dict[str, list[int]] = {}
    for cls in root.iter("class"):
        hits = [int(line.get("hits", "0")) for line in cls.iter("line")]
        # Paths are relative to the measured source, `app/` here.
        entry = files.setdefault(
            f"app/{cls.get('filename', '?')}".replace("\\", "/"), [0, 0]
        )
        entry[0] += sum(1 for h in hits if h)
        entry[1] += len(hits)
    extra = ""
    if int(root.get("branches-valid") or 0):
        extra = f" · **{percent(int(root.get('branches-covered') or 0), int(root.get('branches-valid') or 0))}** of branches"
    return coverage(name, [(p, c, t) for p, (c, t) in files.items()], extra)


def lcov(name: str, path: Path) -> Check:
    """flutter test --coverage's lcov.info."""
    files: list[tuple[str, int, int]] = []
    current, found, hit = "", 0, 0
    for line in lines_of(path):
        if line.startswith("SF:"):
            current, found, hit = line[3:].replace("\\", "/"), 0, 0
        elif line.startswith("DA:"):
            found += 1
            hit += line.split(",")[1] != "0"
        elif line == "end_of_record" and not current.startswith(LCOV_GENERATED):
            files.append((current, hit, found))
    return coverage(name, files)


# --- security -----------------------------------------------------------------


def gitleaks(name: str, path: Path) -> Check:
    leaks = json.loads(path.read_text(encoding="utf-8") or "[]")
    if not leaks:
        return Check(name, "pass", "No secrets in the scanned commits")

    server = os.environ.get("GITHUB_SERVER_URL", "https://github.com")
    repo = os.environ.get("GITHUB_REPOSITORY")
    by_rule: dict[str, int] = {}
    rows: list[list[str]] = []
    for leak in leaks:
        rule = leak.get("RuleID", "?")
        by_rule[rule] = by_rule.get(rule, 0) + 1
        sha = leak.get("Commit", "")
        commit = (
            f"[`{sha[:7]}`]({server}/{repo}/commit/{sha})"
            if sha and repo
            else f"`{sha[:7] or '?'}`"
        )
        # The secret itself is redacted by --redact; only its location is shown.
        rows.append(
            [
                f"`{rule}`",
                f"`{leak.get('File', '?')}:{leak.get('StartLine', '?')}`",
                commit,
            ]
        )
    found = plural(len(leaks), "secret")
    return Check(
        name,
        "fail",
        f"{found} found",
        details(
            f"{found}: {counts(by_rule)}",
            table(["Rule", "Location", "Commit"], rows),
            open_=True,
        ),
        note=(
            f"**{name}** found {found}. Rotate each credential first: "
            "removing it from the branch does not remove it from history."
        ),
    )


# --- rendering ----------------------------------------------------------------


def render(checks: list[Check]) -> list[str]:
    failing = [c for c in checks if c.status == "fail"]
    warning = [c for c in checks if c.status == "warn"]

    lines: list[str] = []
    if failing:
        lines += callout("fail", *[c.note for c in failing])
    if warning:
        lines += callout("warn", *[c.note for c in warning])
    if not failing and not warning:
        lines += callout("pass", "**All checks passed.**")

    lines += table(
        ["", "Check", "Result"],
        [[ICON[c.status], f"**{c.name}**", c.result] for c in checks],
        limit=None,
    )
    for check in checks:
        lines += check.detail
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--ruff", type=Path, help="ruff check --output-format=json report"
    )
    parser.add_argument(
        "--ruff-format-log", type=Path, help="ruff format --check output"
    )
    parser.add_argument(
        "--ty-junit", type=Path, help="ty check --output-format=junit report"
    )
    parser.add_argument("--pytest-junit", type=Path, help="pytest --junitxml report")
    parser.add_argument("--analyze-log", type=Path, help="flutter analyze output")
    parser.add_argument(
        "--dart-format-log", type=Path, help="dart format --set-exit-if-changed output"
    )
    parser.add_argument(
        "--dart-json", type=Path, help="flutter test --file-reporter=json report"
    )
    parser.add_argument(
        "--coverage-xml", type=Path, help="pytest --cov-report=xml report"
    )
    parser.add_argument("--lcov", type=Path, help="flutter test --coverage lcov.info")
    parser.add_argument(
        "--gitleaks", type=Path, help="gitleaks --report-format=json report"
    )
    args = parser.parse_args()

    # Table order follows the order the job runs its steps in.
    plan = [
        ("ruff check", args.ruff, ruff),
        ("ruff format", args.ruff_format_log, ruff_format),
        ("ty check", args.ty_junit, ty_junit),
        ("pytest", args.pytest_junit, pytest_junit),
        ("coverage", args.coverage_xml, cobertura),
        ("flutter analyze", args.analyze_log, flutter_analyze),
        ("dart format", args.dart_format_log, dart_format),
        ("flutter test", args.dart_json, dart_json),
        ("coverage", args.lcov, lcov),
        ("gitleaks", args.gitleaks, gitleaks),
    ]
    checks = [run(name, path, parse) for name, path, parse in plan if path]
    if checks:
        write(render(checks))
    return 0


if __name__ == "__main__":
    sys.exit(main())
