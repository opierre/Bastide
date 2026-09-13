"""Shared pytest fixtures: a TestClient and a DB session, both on temp SQLite databases."""

from collections.abc import Generator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.db import Base, get_db, get_session_factory
from app.features.accounts import models as _accounts_models  # noqa: F401
from app.features.auth import models as _auth_models  # noqa: F401
from app.features.categories import models as _categories_models  # noqa: F401
from app.features.categorization import models as _categorization_models  # noqa: F401
from app.features.goals import models as _goals_models  # noqa: F401
from app.features.imports import models as _imports_models  # noqa: F401
from app.features.mortgages import models as _mortgages_models  # noqa: F401
from app.features.properties import models as _properties_models  # noqa: F401
from app.features.recurring import models as _recurring_models  # noqa: F401
from app.features.rules import models as _rules_models  # noqa: F401
from app.features.settings import models as _settings_models  # noqa: F401
from app.features.transactions import models as _transactions_models  # noqa: F401
from app.main import create_app


@pytest.fixture
def client(tmp_path: Path) -> Generator[TestClient]:
    """A TestClient whose DB session dependency points at a temp SQLite file."""
    engine = create_engine(
        f"sqlite:///{tmp_path / 'test.db'}",
        connect_args={"check_same_thread": False},
    )
    Base.metadata.create_all(engine)
    testing_session_local = sessionmaker(bind=engine, autoflush=False, autocommit=False)

    def override_get_db() -> Generator:
        db = testing_session_local()
        try:
            yield db
        finally:
            db.close()

    app = create_app()
    app.dependency_overrides[get_db] = override_get_db
    # Background work and the startup reconciliation open their own sessions; without this
    # they would open them on the real database instead of this test's temp file.
    app.dependency_overrides[get_session_factory] = lambda: testing_session_local

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
