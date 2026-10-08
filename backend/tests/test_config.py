"""Tests for where the sidecar keeps its datastore."""

from pathlib import Path

import pytest

from app.core import config
from app.core.config import Settings
from app.core.db import sqlite_url


def test_db_path_defaults_to_the_os_users_local_data_dir(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls: list[tuple[str, object, object]] = []

    def fake_user_data_dir(appname: str, appauthor: object, roaming: object) -> str:
        calls.append((appname, appauthor, roaming))
        return str(tmp_path / "FinStride")

    monkeypatch.setattr(config, "user_data_dir", fake_user_data_dir)
    monkeypatch.delenv("FINSTRIDE_DB_PATH", raising=False)

    settings = Settings(_env_file=None)  # ty: ignore[unknown-argument] — pydantic-settings init kwarg

    assert Path(settings.db_path) == tmp_path / "FinStride" / "finstride.db"
    assert calls == [("FinStride", False, False)]


def test_db_path_env_override_wins(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("FINSTRIDE_DB_PATH", "custom.db")

    settings = Settings(_env_file=None)  # ty: ignore[unknown-argument] — pydantic-settings init kwarg

    assert settings.db_path == "custom.db"


def test_sqlite_url_creates_the_missing_data_dir(tmp_path: Path) -> None:
    db_path = tmp_path / "first" / "run" / "finstride.db"

    url = sqlite_url(db_path.as_posix())

    assert url == f"sqlite:///{db_path.as_posix()}"
    assert db_path.parent.is_dir()
    assert not db_path.exists()
