"""Application settings, env-overridable (prefix ``FINSTRIDE_``)."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Sidecar configuration: bind address, datastore path, and secrets."""

    model_config = SettingsConfigDict(env_prefix="FINSTRIDE_", env_file=".env", extra="ignore")

    host: str = "127.0.0.1"
    port: int = 8765
    db_path: str = "finstride.db"
    token_secret: str = "dev-secret-change-me"
    # Regex (not a fixed port) since the Flutter frontend's dev origin/port isn't pinned yet;
    # restricts CORS to loopback origins without falling back to a wildcard.
    frontend_origin_regex: str = r"^http://(127\.0\.0\.1|localhost)(:\d+)?$"


@lru_cache
def get_settings() -> Settings:
    """Return the process-wide settings singleton."""
    return Settings()
