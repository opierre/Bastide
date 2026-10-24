"""Direct database access for tests, on a temp SQLite file a fixture created."""

from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import NullPool


def open_session(db_path: Path) -> Session:
    """A session on ``db_path`` whose SQLite connection closes with it.

    The engine keeps no pool, so `Session.close()` closes the connection rather than parking it
    in a pool nobody disposes — which Python reports as `ResourceWarning: unclosed database`
    whenever the engine is garbage-collected during a later test.
    """
    engine = create_engine(
        f"sqlite:///{db_path}", connect_args={"check_same_thread": False}, poolclass=NullPool
    )
    return sessionmaker(bind=engine)()
