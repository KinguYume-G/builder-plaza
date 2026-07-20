"""Shared fixtures for the API integration tests (test_integration_*.py).

These hit a real FastAPI TestClient + a real Postgres+pgvector database --
never the production RDS. Point DATABASE_URL at a throwaway local instance
(see ../docker-compose.yml) or let it use pgvector/pgvector on localhost:55432
by default. The other 13 test files in this directory are pure unit tests
and are unaffected by anything here.
"""

import os

# Must happen before any `app.*` import: Settings() and the SQLAlchemy
# engine in app/db/base.py are module-level singletons built at import time
# from these env vars, so setting them later would be a no-op.
os.environ.setdefault(
    "DATABASE_URL",
    "postgresql+psycopg://postgres:postgres@localhost:55432/builder_plaza_test",
)
os.environ.setdefault("JWT_SECRET", "test-secret-not-for-prod")
os.environ.setdefault("ENVIRONMENT", "test")

import uuid
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.security import create_access_token
from app.db.base import Base, engine
from app.db.models import User
from app.db.session import get_db


@pytest.fixture(scope="session", autouse=True)
def _schema() -> Iterator[None]:
    """Create the pgvector extension + all tables once per test session."""
    with engine.begin() as conn:
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
    Base.metadata.create_all(engine)
    yield
    Base.metadata.drop_all(engine)


@pytest.fixture()
def db_session() -> Iterator[Session]:
    """One connection + outer transaction per test. The session joins it via
    a SAVEPOINT (SQLAlchemy 2.0's documented test pattern), so app code's own
    `db.commit()` calls never escape it -- the whole test rolls back at the
    end regardless of how many times a route commits."""
    connection = engine.connect()
    trans = connection.begin()
    session = Session(bind=connection, join_transaction_mode="create_savepoint")
    try:
        yield session
    finally:
        session.close()
        trans.rollback()
        connection.close()


@pytest.fixture()
def client(db_session: Session) -> Iterator[TestClient]:
    """TestClient whose `get_db` dependency yields the test's own session, so
    what the API writes is exactly what the test can assert on."""
    from app.main import app

    def _override_get_db() -> Iterator[Session]:
        yield db_session

    app.dependency_overrides[get_db] = _override_get_db
    try:
        with TestClient(app) as test_client:
            yield test_client
    finally:
        app.dependency_overrides.pop(get_db, None)


def make_user(db_session: Session, **overrides) -> User:
    """Insert a minimal, valid User row directly -- bypasses OAuth so tests
    don't depend on GitHub/LinkedIn being reachable."""
    defaults = {
        "github_login": f"user-{uuid.uuid4().hex[:8]}",
        "primary_role": "builder",
        "completeness_pct": 0,
        "trust_score": 0,
        "reverify_flag": False,
        "onboarding_complete": True,
    }
    defaults.update(overrides)
    user = User(**defaults)
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def auth_headers(user: User) -> dict[str, str]:
    return {"Authorization": f"Bearer {create_access_token(str(user.id))}"}
