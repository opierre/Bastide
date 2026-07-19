"""SQLAlchemy engine, session factory, and the per-request session dependency."""

from collections.abc import Generator
from typing import Any

from sqlalchemy import Engine, create_engine, event
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import get_settings


class Base(DeclarativeBase):
    """Declarative base; its metadata is Alembic's autogenerate target."""


settings = get_settings()

engine: Engine = create_engine(
    f"sqlite:///{settings.db_path}",
    connect_args={"check_same_thread": False},
)


@event.listens_for(engine, "connect")
def _enable_wal(dbapi_connection: Any, connection_record: Any) -> None:
    """Enable WAL journal mode so one writer and many readers can coexist."""
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA journal_mode=WAL")
    cursor.close()


SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def get_db() -> Generator[Session]:
    """Yield a database session scoped to a single request."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
