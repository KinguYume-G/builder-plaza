"""API integration: F8 Request Market -- maintainer vs team_role postings,
owner-only mutation, real DB persistence."""

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from tests.conftest import auth_headers, make_user

TEAM_ROLE_PAYLOAD = {
    "posting_type": "team_role",
    "role_desc": "Looking for a Flutter developer to join the founding team.",
    "skills": ["flutter", "dart"],
    "stage": "building",
    "tech_stack": "Flutter + FastAPI",
    "commitment": "10hrs/week",
}


def _create_project(client: TestClient, owner) -> str:
    res = client.post(
        "/projects",
        json={
            "title": "Builder Plaza",
            "stage": "building",
            "repo_full_names": ["octocat/Hello-World"],
        },
        headers=auth_headers(owner),
    )
    assert res.status_code == 201
    return res.json()["id"]


def test_create_team_role_posting(client: TestClient, db_session: Session) -> None:
    owner = make_user(db_session)

    res = client.post(
        "/role-postings", json=TEAM_ROLE_PAYLOAD, headers=auth_headers(owner)
    )

    assert res.status_code == 201
    body = res.json()
    assert body["posting_type"] == "team_role"
    assert body["status"] == "open"


def test_team_role_missing_required_fields_is_422(
    client: TestClient, db_session: Session
) -> None:
    owner = make_user(db_session)
    payload = {**TEAM_ROLE_PAYLOAD, "tech_stack": None, "commitment": None}

    res = client.post("/role-postings", json=payload, headers=auth_headers(owner))

    assert res.status_code == 422


def test_create_maintainer_posting_requires_own_verified_project(
    client: TestClient, db_session: Session
) -> None:
    owner = make_user(db_session)
    project_id = _create_project(client, owner)

    res = client.post(
        "/role-postings",
        json={
            "posting_type": "maintainer",
            "role_desc": "Need help triaging issues on this repo.",
            "project_id": project_id,
            "access_tier": "limited",
        },
        headers=auth_headers(owner),
    )

    assert res.status_code == 201
    assert res.json()["access_tier"] == "limited"


def test_maintainer_posting_on_someone_elses_project_is_rejected(
    client: TestClient, db_session: Session
) -> None:
    owner = make_user(db_session)
    stranger = make_user(db_session)
    project_id = _create_project(client, owner)

    res = client.post(
        "/role-postings",
        json={
            "posting_type": "maintainer",
            "role_desc": "Need help triaging issues on this repo.",
            "project_id": project_id,
            "access_tier": "limited",
        },
        headers=auth_headers(stranger),
    )

    assert res.status_code == 400


def test_only_owner_can_close_posting(client: TestClient, db_session: Session) -> None:
    owner = make_user(db_session)
    stranger = make_user(db_session)
    created = client.post(
        "/role-postings", json=TEAM_ROLE_PAYLOAD, headers=auth_headers(owner)
    )
    posting_id = created.json()["id"]

    forbidden = client.delete(
        f"/role-postings/{posting_id}", headers=auth_headers(stranger)
    )
    assert forbidden.status_code == 403

    closed = client.delete(f"/role-postings/{posting_id}", headers=auth_headers(owner))
    assert closed.status_code == 200
    assert closed.json()["status"] == "closed"


def test_list_filters_by_posting_type(client: TestClient, db_session: Session) -> None:
    owner = make_user(db_session)
    client.post("/role-postings", json=TEAM_ROLE_PAYLOAD, headers=auth_headers(owner))

    res = client.get(
        "/role-postings", params={"posting_type": "maintainer"}, headers=auth_headers(owner)
    )

    assert res.status_code == 200
    assert all(p["posting_type"] == "maintainer" for p in res.json())
