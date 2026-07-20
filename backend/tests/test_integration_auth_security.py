"""Regression tests for the 2026-07-20 security review findings:

1. POST /auth/github/connect must not re-issue a token for an EXISTING,
   fully-onboarded account just because the caller names its public GitHub
   login -- that would be an unauthenticated account takeover, since GitHub
   logins are shown throughout the app (project owners, matches, etc.).
   A not-yet-onboarded account (nothing private to protect yet) must still
   be reachable, so "resume onboarding after reinstall" keeps working.
2. POST /projects/{id}/screenshots must reject a key that wasn't generated
   for that project -- otherwise a user could attach (and then delete)
   another user's S3 object via a project they legitimately own.
"""

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.services.github_provider import GitHubDev
from tests.conftest import auth_headers, make_user

_FAKE_SUMMARY = {
    "login": "octocat",
    "name": "The Octocat",
    "avatar_url": "https://avatars.example/octocat.png",
    "public_repos": 8,
    "followers": 100,
    "top_languages": [],
    "topics": [],
    "recent_activity_count": 5,
    "stars": 42,
}


def _mock_github_fetch(monkeypatch, login: str = "octocat") -> None:
    monkeypatch.setattr(
        GitHubDev, "fetch", lambda self, requested_login: {**_FAKE_SUMMARY, "login": login}
    )


def test_connect_creates_a_brand_new_account(client: TestClient, monkeypatch) -> None:
    _mock_github_fetch(monkeypatch, "octocat")
    res = client.post("/auth/github/connect", json={"github_login": "octocat"})
    assert res.status_code == 200
    assert res.json()["user"]["github_login"] == "octocat"
    assert "access_token" in res.json()


def test_connect_refuses_to_take_over_a_fully_onboarded_account(
    client: TestClient, db_session: Session, monkeypatch
) -> None:
    make_user(db_session, github_login="octocat", onboarding_complete=True)
    _mock_github_fetch(monkeypatch, "octocat")

    res = client.post("/auth/github/connect", json={"github_login": "octocat"})

    assert res.status_code == 409
    assert "access_token" not in res.json()


def test_connect_still_works_for_an_incomplete_onboarding_account(
    client: TestClient, db_session: Session, monkeypatch
) -> None:
    # Legitimate case: e.g. reinstalled mid-onboarding, resuming step 1.
    make_user(db_session, github_login="octocat", onboarding_complete=False)
    _mock_github_fetch(monkeypatch, "octocat")

    res = client.post("/auth/github/connect", json={"github_login": "octocat"})

    assert res.status_code == 200
    assert "access_token" in res.json()


def test_connect_is_case_insensitive_for_the_takeover_guard(
    client: TestClient, db_session: Session, monkeypatch
) -> None:
    make_user(db_session, github_login="OctoCat", onboarding_complete=True)
    _mock_github_fetch(monkeypatch, "octocat")  # GitHub returns canonical casing

    res = client.post("/auth/github/connect", json={"github_login": "OCTOCAT"})

    assert res.status_code == 409


def test_add_screenshot_rejects_a_key_not_belonging_to_the_project(
    client: TestClient, db_session: Session
) -> None:
    owner = make_user(db_session)
    created = client.post(
        "/projects",
        json={"title": "Demo", "stage": "building"},
        headers=auth_headers(owner),
    )
    project_id = created.json()["id"]

    foreign_key = "screenshots/00000000-0000-0000-0000-000000000000/evil.png"
    res = client.post(
        f"/projects/{project_id}/screenshots",
        json={"key": foreign_key},
        headers=auth_headers(owner),
    )

    assert res.status_code == 403
