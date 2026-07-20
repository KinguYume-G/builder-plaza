"""API integration: GET/POST /me* against a real DB + auth (dev doc §17.1's
"API integration: pytest + test DB" layer -- previously missing entirely)."""

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from tests.conftest import auth_headers, make_user


def test_me_returns_current_user(client: TestClient, db_session: Session) -> None:
    user = make_user(db_session, github_login="octocat")

    res = client.get("/me", headers=auth_headers(user))

    assert res.status_code == 200
    body = res.json()
    assert body["github_login"] == "octocat"
    assert body["id"] == str(user.id)


def test_me_without_token_is_401(client: TestClient) -> None:
    res = client.get("/me")
    assert res.status_code == 401


def test_set_role_updates_primary_role(client: TestClient, db_session: Session) -> None:
    user = make_user(db_session, primary_role="builder")

    res = client.post(
        "/me/role", json={"primary_role": "founder"}, headers=auth_headers(user)
    )

    assert res.status_code == 200
    assert res.json()["primary_role"] == "founder"


def test_set_role_completes_onboarding_once_linkedin_already_bound(
    client: TestClient, db_session: Session
) -> None:
    user = make_user(
        db_session,
        onboarding_complete=False,
        linkedin_sub="li-sub-123",
        linkedin_profile={"sub": "li-sub-123", "headline": "Engineer"},
    )

    res = client.post(
        "/me/role", json={"primary_role": "collaborator"}, headers=auth_headers(user)
    )

    assert res.status_code == 200
    assert res.json()["onboarding_complete"] is True


def test_set_role_invalid_role_is_422(client: TestClient, db_session: Session) -> None:
    user = make_user(db_session)

    res = client.post(
        "/me/role", json={"primary_role": "astronaut"}, headers=auth_headers(user)
    )

    assert res.status_code == 422
