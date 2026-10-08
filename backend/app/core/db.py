"""SQLAlchemy engine, session factory, and the per-request session dependency."""

from collections.abc import Callable, Generator
from pathlib import Path
from typing import Any

from sqlalchemy import Engine, create_engine, event
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import get_settings


class Base(DeclarativeBase):
    """Declarative base; its metadata is Alembic's autogenerate target."""


def sqlite_url(db_path: str) -> str:
    """Return the SQLAlchemy URL for `db_path`, creating its folder on first use.

    SQLite creates a missing file but not a missing folder, and the per-user data dir does not
    exist until the sidecar first runs for that OS account.
    """
    Path(db_path).parent.mkdir(parents=True, exist_ok=True)
    return f"sqlite:///{db_path}"


def configure_sqlite(engine: Engine) -> Engine:
    """Apply the pragmas every app connection needs, and return the engine.

    WAL lets one writer and many readers coexist. Foreign keys are declared in the schema but
    SQLite only enforces them — cascades included — when each connection opts in; without it a
    dangling reference is stored silently, where Postgres would reject it.

    Alembic deliberately keeps its own engine without these: batch migrations rebuild tables,
    and with foreign keys on, dropping the old copy would cascade into the rows that point at it.
    """

    @event.listens_for(engine, "connect")
    def _set_pragmas(dbapi_connection: Any, connection_record: Any) -> None:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    return engine


settings = get_settings()

engine: Engine = configure_sqlite(
    create_engine(
        sqlite_url(settings.db_path),
        connect_args={"check_same_thread": False},
    )
)


SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


#: Opens a session with no request bound to its lifetime.
type SessionFactory = Callable[[], Session]


def get_db() -> Generator[Session]:
    """Yield a database session scoped to a single request."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_session_factory() -> SessionFactory:
    """Return the factory background work opens its own sessions with.

    Work that outlives the request that started it — a categorisation run, which returns 202
    and then keeps writing — cannot borrow the request's session: `get_db` closes it as soon
    as the response is sent. It takes the factory instead and owns the session it opens.
    Exposed as a dependency so tests can point background work at their temp database, the
    same way they override `get_db`.
    """
    return SessionLocal
