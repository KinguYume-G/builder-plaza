"""GitHub OAuth 2.0 authorization-code flow (F1 Dual-Source Trust Gateway).

Only the identity leg lives here: redirect the user to GitHub, swap the
returned ``code`` for an access token, and read back the GitHub login. The
Trust Gateway's richer ingestion (repos, language mix, 90-day activity,
topics) is a later step that reuses the same access token.
"""

from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode

import httpx
import jwt

from app.core.config import settings
from app.core.security import ALGORITHM

GITHUB_AUTHORIZE_URL = "https://github.com/login/oauth/authorize"
GITHUB_TOKEN_URL = "https://github.com/login/oauth/access_token"
GITHUB_USER_URL = "https://api.github.com/user"

# Only public profile data is needed for the identity leg.
OAUTH_SCOPE = "read:user"

# The `state` param is a short-lived JWT we sign ourselves, so the callback can
# verify it came from us (CSRF defence) without any server-side session store.
_STATE_MARKER = "github_oauth_state"
_STATE_TTL = timedelta(minutes=10)


class GitHubOAuthError(Exception):
    """Raised when GitHub rejects the token exchange or the profile fetch."""


def build_authorize_url(state: str) -> str:
    params = {
        "client_id": settings.github_client_id,
        "redirect_uri": settings.github_redirect_uri,
        "scope": OAUTH_SCOPE,
        "state": state,
        "allow_signup": "true",
    }
    return f"{GITHUB_AUTHORIZE_URL}?{urlencode(params)}"


def create_state_token() -> str:
    now = datetime.now(timezone.utc)
    payload = {"mark": _STATE_MARKER, "exp": now + _STATE_TTL}
    return jwt.encode(payload, settings.jwt_secret, algorithm=ALGORITHM)


def verify_state_token(state: str) -> bool:
    try:
        payload = jwt.decode(state, settings.jwt_secret, algorithms=[ALGORITHM])
    except jwt.InvalidTokenError:
        return False
    return payload.get("mark") == _STATE_MARKER


async def exchange_code_for_token(code: str) -> str:
    """Swap an authorization ``code`` for a GitHub access token."""
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(
            GITHUB_TOKEN_URL,
            headers={"Accept": "application/json"},
            data={
                "client_id": settings.github_client_id,
                "client_secret": settings.github_client_secret,
                "code": code,
                "redirect_uri": settings.github_redirect_uri,
            },
        )

    if response.status_code != 200:
        raise GitHubOAuthError(f"token exchange failed: HTTP {response.status_code}")

    body = response.json()
    # GitHub returns HTTP 200 with an `error` field on bad codes, not a 4xx.
    if "error" in body:
        raise GitHubOAuthError(body.get("error_description", body["error"]))

    token = body.get("access_token")
    if not token:
        raise GitHubOAuthError("token exchange returned no access_token")
    return token


async def fetch_github_login(access_token: str) -> str:
    """Return the authenticated user's GitHub login (username)."""
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.get(
            GITHUB_USER_URL,
            headers={
                "Authorization": f"Bearer {access_token}",
                "Accept": "application/vnd.github+json",
            },
        )

    if response.status_code != 200:
        raise GitHubOAuthError(f"profile fetch failed: HTTP {response.status_code}")

    login = response.json().get("login")
    if not login:
        raise GitHubOAuthError("profile response had no login")
    return login
