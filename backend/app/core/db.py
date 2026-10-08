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


settings = get_settings()

engine: Engine = create_engine(
    sqlite_url(settings.db_path),
    connect_args={"check_same_thread": False},
)


@event.listens_for(engine, "connect")
def _enable_wal(dbapi_connection: Any, connection_record: Any) -> None:
    """Enable WAL journal mode so one writer and many readers can coexist."""
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA journal_mode=WAL")
    cursor.close()


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
