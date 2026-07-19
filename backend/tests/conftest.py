"""Shared pytest fixtures: a TestClient and a DB session, both on temp SQLite databases."""

from collections.abc import Generator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.db import Base, get_db
from app.features.accounts import models as _accounts_models  # noqa: F401
from app.features.auth import models as _auth_models  # noqa: F401
from app.features.categories import models as _categories_models  # noqa: F401
from app.features.imports import models as _imports_models  # noqa: F401
from app.features.rules import models as _rules_models  # noqa: F401
from app.features.transactions import models as _transactions_models  # noqa: F401
from app.main import create_app


@pytest.fixture
def client(tmp_path: Path) -> Generator[TestClient]:
    """A TestClient whose DB session dependency points at a temp SQLite file."""
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}",
        connect_args={"check_same_thread": False},
    )
    testing_session_local = sessionmaker(bind=engine, autoflush=False, autocommit=False)

    def override_get_db() -> Generator:
        db = testing_session_local()
        try:
            yield db
        finally:
            db.close()

    app = create_app()
    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def db_session(tmp_path: Path) -> Generator[Session]:
    """A Session on a temp SQLite database built from the ORM metadata (all feature models)."""
    engine = create_engine(
        f"sqlite:///{tmp_path / 'models.db'}",
        connect_args={"check_same_thread": False},
    )
    Base.metadata.create_all(engine)
    session_local = sessionmaker(bind=engine, autoflush=False, autocommit=False)

    db = session_local()
    try:
        yield db
    finally:
        db.close()
