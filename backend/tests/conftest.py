"""Shared pytest fixtures: a TestClient and DB sessions, all on temp SQLite databases.

Every database a test gets is a copy of a template built once per session: a schema costs a file
copy per test rather than a `create_all`, and a migrated one a copy rather than a full Alembic run.
"""

import shutil
from collections.abc import Generator
from pathlib import Path
from unittest.mock import patch

import pytest
from argon2 import PasswordHasher
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core import security
from app.core.db import Base, get_db, get_session_factory
from app.core.seed import seed_categories
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
from tests.migrations import engine_with_foreign_keys, upgrade


@pytest.fixture(scope="session", autouse=True)
def _cheap_password_hashing() -> Generator[None]:
    """Argon2id at its minimum cost for the whole session.

    Still Argon2id, still verified against its own hash, but a hash costs microseconds instead
    of the ~40 ms the production parameters spend on every register and login in every test.
    """
    hasher = PasswordHasher(time_cost=1, memory_cost=8, parallelism=1)
    with patch.object(security, "_password_hasher", hasher):
        yield


@pytest.fixture(scope="session")
def schema_template(tmp_path_factory: pytest.TempPathFactory) -> Path:
    """An empty database built from the ORM metadata (all feature models)."""
    path = tmp_path_factory.mktemp("templates") / "schema.db"
    engine = create_engine(f"sqlite:///{path}")
    Base.metadata.create_all(engine)
    engine.dispose()
    return path


@pytest.fixture(scope="session")
def seeded_template(schema_template: Path) -> Path:
    """The schema template plus the system category catalog, as the app's startup leaves it."""
    path = schema_template.with_name("seeded.db")
    shutil.copyfile(schema_template, path)
    engine = create_engine(f"sqlite:///{path}")
    with Session(engine) as db:
        seed_categories(db)
    engine.dispose()
    return path


@pytest.fixture(scope="session")
def migrated_template(tmp_path_factory: pytest.TempPathFactory) -> Path:
    """An empty database brought to head by Alembic, rather than by `create_all`."""
    path = tmp_path_factory.mktemp("templates") / "migrated.db"
    upgrade(path)
    return path


@pytest.fixture
def client(tmp_path: Path, seeded_template: Path) -> Generator[TestClient]:
    """A TestClient whose DB session dependency points at a temp SQLite file."""
    db_path = tmp_path / "test.db"
    shutil.copyfile(seeded_template, db_path)
    engine = create_engine(f"sqlite:///{db_path}", connect_args={"check_same_thread": False})
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
def db_session(tmp_path: Path, schema_template: Path) -> Generator[Session]:
    """A Session on an empty temp database built from the ORM metadata (all feature models)."""
    db_path = tmp_path / "models.db"
    shutil.copyfile(schema_template, db_path)
    engine = create_engine(f"sqlite:///{db_path}", connect_args={"check_same_thread": False})
    db = sessionmaker(bind=engine, autoflush=False, autocommit=False)()
    try:
        yield db
    finally:
        db.close()
        engine.dispose()


@pytest.fixture
def migrated_session(tmp_path: Path, migrated_template: Path) -> Generator[Session]:
    """A Session on a temp database built by Alembic, with FK enforcement on."""
    db_path = tmp_path / "migrated.db"
    shutil.copyfile(migrated_template, db_path)
    engine = engine_with_foreign_keys(db_path)
    db = sessionmaker(bind=engine, autoflush=False, autocommit=False)()
    try:
        yield db
    finally:
        db.close()
        engine.dispose()
