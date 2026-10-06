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

from summary_md import callout, details, plural, table, write

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
    __slots__ = ("ecosystem", "ids", "package", "severity", "source", "version")

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


SEVERITY_ICON = {
    "CRITICAL": "🔴",
    "HIGH": "🟠",
    "MEDIUM": "🟡",
    "LOW": "🔵",
    "UNKNOWN": "⚪",
}


def render(title: str, findings: list[Finding], *, open_: bool = False) -> list[str]:
    if not findings:
        return []
    rows = []
    for f in sorted(findings, key=lambda f: -RANK[f.severity]):
        rows.append(
            [
                f"{SEVERITY_ICON[f.severity]} {f.severity.title()}",
                f"`{f.package}` {f.version}",
                f.ecosystem,
                f"[{f.primary_id}](https://osv.dev/{f.primary_id})",
                f"`{f.source}`",
            ]
        )
    body = table(
        ["Severity", "Package", "Ecosystem", "Advisory", "Lockfile"], rows, limit=None
    )
    return details(f"{title} ({len(findings)})", body, open_=open_)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--results", type=Path, required=True, help="osv-scanner JSON report"
    )
    ap.add_argument(
        "--baseline",
        type=Path,
        help="report for the base ref; its findings never fail the build",
    )
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

    rule = "High and Critical" if args.threshold == "high" else "any severity"
    scope = "introduced by this PR" if baseline_keys else "across the whole tree"
    summary: list[str] = []
    if blocking:
        summary += callout(
            "fail",
            f"**{plural(len(blocking), 'vulnerable dependency', 'vulnerable dependencies')} "
            f"{'blocks' if len(blocking) == 1 else 'block'} this build.**",
            f"The gate fails on {rule} findings {scope}. Upgrade the package or pin a fixed version.",
        )
    elif tolerated:
        summary += callout(
            "warn",
            f"**{plural(len(tolerated), 'advisory', 'advisories')} below the blocking threshold.**",
            f"Not blocking: the gate fails on {rule} findings {scope}. Worth a look before merging.",
        )
    elif inherited:
        summary += callout(
            "info",
            f"**Nothing new.** {plural(len(inherited), 'advisory', 'advisories')} "
            "already present on the base branch; this PR does not add any.",
        )
    else:
        summary += callout(
            "pass", "**No known vulnerabilities** in `uv.lock` or `pubspec.lock`."
        )
    summary += render("Blocking", blocking, open_=True)
    summary += render("Below threshold", tolerated, open_=not blocking)
    summary += render("Already on the base branch", inherited)

    write(summary)

    for f in blocking:
        print(
            f"::error::{f.severity} {f.primary_id} in {f.ecosystem}/{f.package}@{f.version} ({f.source})"
        )

    return 1 if blocking else 0


if __name__ == "__main__":
    sys.exit(main())
