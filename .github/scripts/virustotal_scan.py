#!/usr/bin/env python3
"""Scan release packages with VirusTotal and report what its engines say.

  VIRUSTOTAL_API_KEY=... virustotal_scan.py dist/Bastide-*

Uploads each file, waits for its analysis, and prints a Markdown table with the
detection counts and a link to each report (appended to $GITHUB_STEP_SUMMARY when
set). Exits 1 when any engine calls a file malicious, so a flagged build is caught
before the draft release is published by hand; "suspicious" verdicts are only
reported, since generic heuristics raise them on many unsigned programs.

The packages are public once the release is, so uploading them reveals nothing new.
Paced for the free public API (4 requests a minute). Runs on the runner's system
Python; standard library only.
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

API = "https://www.virustotal.com/api/v3"
# Files above this size go through a one-off upload URL instead of /files.
DIRECT_UPLOAD_LIMIT = 32 * 1024 * 1024
# The public API allows 4 requests a minute.
REQUEST_INTERVAL = 16.0
# A large package can sit in VirusTotal's queue for a while.
ANALYSIS_TIMEOUT = 30 * 60


class Client:
    def __init__(self, api_key: str) -> None:
        self.api_key = api_key
        self.last_request = 0.0

    def request(
        self, url: str, *, data: bytes | None = None, content_type: str | None = None
    ) -> dict:
        wait = self.last_request + REQUEST_INTERVAL - time.monotonic()
        if wait > 0:
            time.sleep(wait)
        headers = {"x-apikey": self.api_key, "accept": "application/json"}
        if content_type is not None:
            headers["content-type"] = content_type
        request = urllib.request.Request(url, data=data, headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=600) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            sys.exit(f"::error::VirusTotal answered {error.code}: {error.read().decode()[:500]}")
        finally:
            self.last_request = time.monotonic()

    def upload(self, path: Path) -> str:
        """Upload ``path`` and return the id of its analysis."""
        url = f"{API}/files"
        if path.stat().st_size > DIRECT_UPLOAD_LIMIT:
            url = self.request(f"{API}/files/upload_url")["data"]
        boundary = uuid.uuid4().hex
        body = b"".join(
            [
                f"--{boundary}\r\n".encode(),
                f'Content-Disposition: form-data; name="file"; filename="{path.name}"\r\n'.encode(),
                b"Content-Type: application/octet-stream\r\n\r\n",
                path.read_bytes(),
                f"\r\n--{boundary}--\r\n".encode(),
            ]
        )
        answer = self.request(
            url, data=body, content_type=f"multipart/form-data; boundary={boundary}"
        )
        return answer["data"]["id"]

    def wait_for(self, analysis_id: str, deadline: float) -> dict:
        """The detection stats of a finished analysis."""
        while True:
            attributes = self.request(f"{API}/analyses/{analysis_id}")["data"]["attributes"]
            if attributes["status"] == "completed":
                return attributes["stats"]
            if time.monotonic() > deadline:
                sys.exit(f"::error::VirusTotal analysis {analysis_id} did not finish in time")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    api_key = os.environ.get("VIRUSTOTAL_API_KEY", "")
    if not api_key:
        sys.exit("::error::VIRUSTOTAL_API_KEY is not set")
    paths = [Path(arg) for arg in sys.argv[1:]]
    if not paths:
        sys.exit("usage: virustotal_scan.py FILE...")

    client = Client(api_key)
    # Upload everything first: the analyses then run side by side while we wait.
    analyses = {}
    for path in paths:
        print(f"Uploading {path.name}", flush=True)
        analyses[path] = client.upload(path)

    deadline = time.monotonic() + ANALYSIS_TIMEOUT
    lines = [
        "## VirusTotal",
        "",
        "| File | Malicious | Suspicious | Report |",
        "| --- | ---: | ---: | --- |",
    ]
    flagged = []
    for path, analysis_id in analyses.items():
        stats = client.wait_for(analysis_id, deadline)
        malicious, suspicious = stats.get("malicious", 0), stats.get("suspicious", 0)
        if malicious:
            flagged.append(path.name)
        report = f"https://www.virustotal.com/gui/file/{sha256(path)}"
        lines.append(f"| `{path.name}` | {malicious} | {suspicious} | [report]({report}) |")
        print(f"{path.name}: {malicious} malicious, {suspicious} suspicious", flush=True)

    table = "\n".join(lines) + "\n"
    print(table)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as file:
            file.write(table)

    if flagged:
        print(
            f"::error::Flagged as malicious: {', '.join(flagged)}. Check the reports, and if"
            " they are false positives, submit the files to the vendors before publishing."
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
