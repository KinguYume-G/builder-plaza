"""API integration: auth gating against a real DB. Covers dev doc §17.3's
negative/security cases that the pure unit suite (test_security.py) can't
reach because it never goes through an actual protected route."""

import jwt
from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import ALGORITHM
from tests.conftest import make_user


def test_dev_login_is_forbidden_outside_local_environment(client: TestClient) -> None:
    # conftest sets ENVIRONMENT=test so the shortcut must stay closed; only
    # `local` may mint tokens without real GitHub/LinkedIn verification.
    res = client.post(
        "/auth/dev-login",
        json={"github_login": "someone", "primary_role": "builder"},
    )
    assert res.status_code == 403


def test_protected_route_without_token_is_401(client: TestClient) -> None:
    res = client.get("/me")
    assert res.status_code == 401


def test_protected_route_with_garbage_token_is_401(client: TestClient) -> None:
    res = client.get("/me", headers={"Authorization": "Bearer not-a-real-token"})
    assert res.status_code == 401


def test_protected_route_with_expired_token_is_401(
    client: TestClient, db_session: Session
) -> None:
    user = make_user(db_session)
    expired = jwt.encode(
        {"sub": str(user.id), "exp": datetime.now(timezone.utc) - timedelta(days=1)},
        settings.jwt_secret,
        algorithm=ALGORITHM,
    )
    res = client.get("/me", headers={"Authorization": f"Bearer {expired}"})
    assert res.status_code == 401


def test_protected_route_with_wrong_secret_token_is_401(
    client: TestClient, db_session: Session
) -> None:
    user = make_user(db_session)
    forged = jwt.encode(
        {"sub": str(user.id), "exp": datetime.now(timezone.utc) + timedelta(days=1)},
        "not-the-real-secret",
        algorithm=ALGORITHM,
    )
    res = client.get("/me", headers={"Authorization": f"Bearer {forged}"})
    assert res.status_code == 401


def test_protected_route_for_deleted_user_is_401(client: TestClient) -> None:
    from app.core.security import create_access_token

    token = create_access_token("00000000-0000-0000-0000-000000000000")
    res = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 401
