from urllib.parse import parse_qs, urlparse

from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import app
from app.services import github_oauth

# No network: exercises the authorize-URL build, state signing, and the
# login-redirect endpoint. The token exchange / profile fetch (which hit
# GitHub) are not covered here.

client = TestClient(app, follow_redirects=False)


def test_state_token_round_trip() -> None:
    state = github_oauth.create_state_token()

    assert github_oauth.verify_state_token(state) is True


def test_verify_rejects_garbage_state() -> None:
    assert github_oauth.verify_state_token("not-a-real-token") is False


def test_build_authorize_url_carries_client_id_and_redirect() -> None:
    url = github_oauth.build_authorize_url("some-state")
    query = parse_qs(urlparse(url).query)

    assert url.startswith(github_oauth.GITHUB_AUTHORIZE_URL)
    assert query["client_id"] == [settings.github_client_id]
    assert query["redirect_uri"] == [settings.github_redirect_uri]
    assert query["state"] == ["some-state"]


def test_login_redirects_to_github() -> None:
    response = client.get("/auth/github/login")

    assert response.status_code == 307
    location = response.headers["location"]
    assert location.startswith(github_oauth.GITHUB_AUTHORIZE_URL)
    # A signed, verifiable state must ride along for CSRF defence.
    state = parse_qs(urlparse(location).query)["state"][0]
    assert github_oauth.verify_state_token(state) is True


def test_callback_rejects_bad_state() -> None:
    response = client.get("/auth/github/callback", params={"code": "x", "state": "forged"})

    assert response.status_code == 400
