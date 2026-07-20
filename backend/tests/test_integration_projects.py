"""API integration: F3 Project Card CRUD + ownership against a real DB."""

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from tests.conftest import auth_headers, make_user

VALID_PAYLOAD = {
    "title": "VectorDB Proxy",
    "stage": "building",
    "needs": "Looking for a Rust contributor",
    "repo_full_names": ["octocat/Hello-World"],
}


def test_create_then_get_then_list(client: TestClient, db_session: Session) -> None:
    owner = make_user(db_session)

    created = client.post("/projects", json=VALID_PAYLOAD, headers=auth_headers(owner))
    assert created.status_code == 201
    body = created.json()
    assert body["title"] == "VectorDB Proxy"
    assert body["owner_id"] == str(owner.id)
    assert body["status"] == "active"
    project_id = body["id"]

    fetched = client.get(f"/projects/{project_id}")
    assert fetched.status_code == 200
    assert fetched.json()["id"] == project_id

    listed = client.get("/projects")
    assert listed.status_code == 200
    assert any(p["id"] == project_id for p in listed.json())


def test_owner_can_patch_own_project(client: TestClient, db_session: Session) -> None:
    owner = make_user(db_session)
    created = client.post("/projects", json=VALID_PAYLOAD, headers=auth_headers(owner))
    project_id = created.json()["id"]

    patched = client.patch(
        f"/projects/{project_id}",
        json={"title": "VectorDB Proxy v2"},
        headers=auth_headers(owner),
    )

    assert patched.status_code == 200
    assert patched.json()["title"] == "VectorDB Proxy v2"


def test_non_owner_cannot_patch_project(client: TestClient, db_session: Session) -> None:
    owner = make_user(db_session)
    stranger = make_user(db_session)
    created = client.post("/projects", json=VALID_PAYLOAD, headers=auth_headers(owner))
    project_id = created.json()["id"]

    res = client.patch(
        f"/projects/{project_id}",
        json={"title": "Hijacked"},
        headers=auth_headers(stranger),
    )

    assert res.status_code == 403


def test_archive_is_soft_delete(client: TestClient, db_session: Session) -> None:
    owner = make_user(db_session)
    created = client.post("/projects", json=VALID_PAYLOAD, headers=auth_headers(owner))
    project_id = created.json()["id"]

    archived = client.delete(f"/projects/{project_id}", headers=auth_headers(owner))
    assert archived.status_code == 200
    assert archived.json()["status"] == "archived"

    # Archived cards drop out of the public discovery feed...
    listed = client.get("/projects")
    assert all(p["id"] != project_id for p in listed.json())
    # ...but the row itself still exists and is directly fetchable.
    fetched = client.get(f"/projects/{project_id}")
    assert fetched.status_code == 200
    assert fetched.json()["status"] == "archived"


def test_create_without_token_is_401(client: TestClient) -> None:
    res = client.post("/projects", json=VALID_PAYLOAD)
    assert res.status_code == 401


def test_create_with_invalid_stage_is_422(client: TestClient, db_session: Session) -> None:
    owner = make_user(db_session)
    payload = {**VALID_PAYLOAD, "stage": "not-a-real-stage"}

    res = client.post("/projects", json=payload, headers=auth_headers(owner))

    assert res.status_code == 422


def test_get_missing_project_is_404(client: TestClient) -> None:
    res = client.get("/projects/00000000-0000-0000-0000-000000000000")
    assert res.status_code == 404
