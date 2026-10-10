"""Tests for the hand-built TLS context outgoing clients use."""

import ssl
from pathlib import Path

import pytest

from app.core.tls import tls_context


def test_the_context_never_opens_a_key_log(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """Antivirus sets SSLKEYLOGFILE; opening that key log aborts the process on Windows.

    `ssl.create_default_context()` is not called here to show the hazard: on Windows it
    is the abort.
    """
    monkeypatch.setenv("SSLKEYLOGFILE", str(tmp_path / "keys.log"))

    assert tls_context().keylog_filename is None
    assert not (tmp_path / "keys.log").exists()


def test_the_context_still_verifies_certificates() -> None:
    context = tls_context()

    assert context.verify_mode == ssl.CERT_REQUIRED
    assert context.check_hostname
    assert context.cert_store_stats()["x509_ca"] > 0
