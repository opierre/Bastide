"""Application settings, env-overridable (prefix ``BASTIDE_``)."""

from functools import lru_cache
from pathlib import Path

from platformdirs import user_data_dir
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Sidecar configuration: bind address, datastore path, and allowed CORS origins."""

    model_config = SettingsConfigDict(env_prefix="BASTIDE_", env_file=".env", extra="ignore")

    host: str = "127.0.0.1"
    # Each OS account gets its own datastore under its private data dir (%LOCALAPPDATA% on
    # Windows, ~/Library/Application Support on macOS, ~/.local/share on Linux), so the OS file
    # permissions keep one person's finances from another's, not only the app's login.
    db_path: str = Field(default_factory=lambda: default_db_path().as_posix())
    # Regex (not a fixed port) since the Flutter frontend's dev origin/port isn't pinned yet;
    # restricts CORS to loopback origins without falling back to a wildcard.
    frontend_origin_regex: str = r"^http://(127\.0\.0\.1|localhost)(:\d+)?$"
    # Set by the desktop app on every launch (`app.core.session`). Unset in dev, where the
    # API then answers any local caller.
    session_token: str | None = None


def default_db_path() -> Path:
    """Return the datastore path inside the current OS user's local (non-roaming) data dir."""
    # Local, not roaming: a SQLite file and its WAL must stay on a local disk, never synced.
    return Path(user_data_dir("Bastide", appauthor=False, roaming=False)) / "bastide.db"


@lru_cache
def get_settings() -> Settings:
    """Return the process-wide settings singleton."""
    return Settings()
