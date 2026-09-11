#!/usr/bin/env python3
"""Apply FinStride's severity policy to an osv-scanner JSON report.

osv-scanner exits 1 whenever it finds anything, with no severity threshold of
its own. This script reads its JSON output and decides whether the job fails:

  --threshold high   fail on CRITICAL/HIGH only  (pull requests)
  --threshold any    fail on anything, UNKNOWN included  (main, scheduled)

With --baseline, findings already present on the base ref are reported but do
not fail the build, so a PR is only blamed for what it actually introduces.

Severity comes from each alias group's `max_severity` (a CVSS base score that
osv-scanner computes). Entries without one are reported as UNKNOWN, which is
tolerated on a PR but fails on main - that forces a human decision rather than
letting an unscored advisory through silently.

Runs on the runner's system Python; standard library only.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

# CVSS v3 qualitative rating scale.
RANK = {"CRITICAL": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1, "UNKNOWN": 0}


def severity_of(max_severity: str | None) -> str:
    """Map a CVSS base score to its qualitative rating."""
    if not max_severity:
        return "UNKNOWN"
    try:
        score = float(max_severity)
    except ValueError:
        return "UNKNOWN"
    if score >= 9.0:
        return "CRITICAL"
    if score >= 7.0:
        return "HIGH"
    if score >= 4.0:
        return "MEDIUM"
    if score > 0.0:
        return "LOW"
    return "UNKNOWN"


class Finding:
    __slots__ = ("ecosystem", "package", "version", "ids", "severity", "source")

    def __init__(
        self,
        ecosystem: str,
        package: str,
        version: str,
        ids: list[str],
        severity: str,
        source: str,
    ) -> None:
        self.ecosystem = ecosystem
        self.package = package
        self.version = version
        self.ids = ids
        self.severity = severity
        self.source = source

    @property
    def key(self) -> tuple[str, str, tuple[str, ...]]:
        """Identity for baseline comparison - deliberately excludes the version.

        A version bump that keeps the same advisory is still the same finding;
        one that fixes it makes the finding disappear from the report entirely.
        """
        return (self.ecosystem, self.package, tuple(sorted(self.ids)))

    @property
    def primary_id(self) -> str:
        return self.ids[0] if self.ids else "?"


def parse(path: Path) -> list[Finding]:
    with path.open(encoding="utf-8") as fh:
        data = json.load(fh)

    findings: list[Finding] = []
    for result in data.get("results") or []:
        source = (result.get("source") or {}).get("path", "")
        for entry in result.get("packages") or []:
            pkg = entry.get("package") or {}
            name = pkg.get("name", "?")
            version = pkg.get("version", "?")
            ecosystem = pkg.get("ecosystem", "?")
            for group in entry.get("groups") or []:
                ids = [i for i in (group.get("ids") or []) if i]
                if not ids:
                    continue
                findings.append(
                    Finding(
                        ecosystem=ecosystem,
                        package=name,
                        version=version,
                        ids=ids,
                        severity=severity_of(group.get("max_severity")),
                        source=os.path.basename(source),
                    )
                )
    return findings


def render(title: str, findings: list[Finding]) -> list[str]:
    if not findings:
        return []
    lines = [f"### {title}", "", "| Severity | Package | Version | Advisory | Lockfile |", "| --- | --- | --- | --- | --- |"]
    for f in sorted(findings, key=lambda f: -RANK[f.severity]):
        advisory = f"[{f.primary_id}](https://osv.dev/{f.primary_id})"
        lines.append(
            f"| {f.severity} | `{f.ecosystem}/{f.package}` | {f.version} | {advisory} | {f.source} |"
        )
    lines.append("")
    return lines


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--results", type=Path, required=True, help="osv-scanner JSON report")
    ap.add_argument("--baseline", type=Path, help="report for the base ref; its findings never fail the build")
    ap.add_argument("--threshold", choices=("high", "any"), required=True)
    args = ap.parse_args()

    findings = parse(args.results)

    baseline_keys: set[tuple[str, str, tuple[str, ...]]] = set()
    if args.baseline and args.baseline.exists():
        baseline_keys = {f.key for f in parse(args.baseline)}

    new = [f for f in findings if f.key not in baseline_keys]
    inherited = [f for f in findings if f.key in baseline_keys]

    if args.threshold == "high":
        blocking = [f for f in new if RANK[f.severity] >= RANK["HIGH"]]
    else:
        blocking = list(new)

    tolerated = [f for f in new if f not in blocking]

    summary: list[str] = ["## Dependency vulnerability scan", ""]
    scope = "new in this PR" if baseline_keys else "whole tree"
    summary.append(
        f"Threshold `{args.threshold}` | scope _{scope}_ | "
        f"{len(blocking)} blocking, {len(tolerated)} reported, {len(inherited)} pre-existing."
    )
    summary.append("")
    summary += render("Blocking", blocking)
    summary += render("Reported (below threshold)", tolerated)
    summary += render("Pre-existing on the base ref", inherited)
    if not findings:
        summary.append("No known vulnerabilities. :white_check_mark:")

    text = "\n".join(summary)
    print(text)
    step_summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if step_summary:
        with open(step_summary, "a", encoding="utf-8") as fh:
            fh.write(text + "\n")

    for f in blocking:
        print(
            f"::error::{f.severity} {f.primary_id} in {f.ecosystem}/{f.package}@{f.version} ({f.source})"
        )

    return 1 if blocking else 0


if __name__ == "__main__":
    sys.exit(main())
