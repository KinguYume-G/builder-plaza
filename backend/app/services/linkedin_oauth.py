"""LinkedIn "Sign In with LinkedIn using OpenID Connect" flow (F1, ADR-0003 live path).

The production sibling of ``identity_provider.LinkedInSimulated``. This module
runs the real OIDC authorization-code flow: redirect the user to LinkedIn, swap
the returned ``code`` for an access token, and read the OIDC userinfo claims.

OIDC userinfo returns identity claims only (``sub``, ``name``, ``email``,
``picture`` ...). It does NOT expose employment fields (job title, company,
tenure), so ``map_userinfo_to_profile`` leaves those null rather than fabricating
them, while keeping the same key shape as the simulated profile so ``UserOut``
stays uniform downstream.
"""

from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode

import httpx
import jwt

from app.core.config import settings
from app.core.security import ALGORITHM

LINKEDIN_AUTHORIZE_URL = "https://www.linkedin.com/oauth/v2/authorization"
LINKEDIN_TOKEN_URL = "https://www.linkedin.com/oauth/v2/accessToken"
LINKEDIN_USERINFO_URL = "https://api.linkedin.com/v2/userinfo"

# OIDC scopes for the identity leg: openid (sub), profile (name/picture), email.
OIDC_SCOPE = "openid profile email"

# The `state` param is a short-lived JWT we sign ourselves so the callback can
# verify it came from us (CSRF defence) AND recover which logged-in user started
# the bind, without any server-side session store.
_STATE_MARKER = "linkedin_oauth_state"
_STATE_TTL = timedelta(minutes=10)


class LinkedInOAuthError(Exception):
    """Raised when LinkedIn rejects the token exchange or the userinfo fetch."""


def build_authorize_url(state: str) -> str:
    params = {
        "response_type": "code",
        "client_id": settings.linkedin_client_id,
        "redirect_uri": settings.linkedin_redirect_uri,
        "scope": OIDC_SCOPE,
        "state": state,
    }
    return f"{LINKEDIN_AUTHORIZE_URL}?{urlencode(params)}"


def create_state_token(user_id: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {"mark": _STATE_MARKER, "sub": str(user_id), "exp": now + _STATE_TTL}
    return jwt.encode(payload, settings.jwt_secret, algorithm=ALGORITHM)


def verify_state_token(state: str) -> str | None:
    """Return the user_id (sub) if the state is a valid, unexpired token we
    signed with the right marker; otherwise None."""
    try:
        payload = jwt.decode(state, settings.jwt_secret, algorithms=[ALGORITHM])
    except jwt.InvalidTokenError:
        return None
    if payload.get("mark") != _STATE_MARKER:
        return None
    return payload.get("sub")


async def exchange_code_for_token(code: str) -> str:
    """Swap an authorization ``code`` for a LinkedIn access token."""
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(
            LINKEDIN_TOKEN_URL,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            data={
                "grant_type": "authorization_code",
                "code": code,
                "client_id": settings.linkedin_client_id,
                "client_secret": settings.linkedin_client_secret,
                "redirect_uri": settings.linkedin_redirect_uri,
            },
        )

    if response.status_code != 200:
        raise LinkedInOAuthError(f"token exchange failed: HTTP {response.status_code}")

    body = response.json()
    if "error" in body:
        raise LinkedInOAuthError(body.get("error_description", body["error"]))

    token = body.get("access_token")
    if not token:
        raise LinkedInOAuthError("token exchange returned no access_token")
    return token


async def fetch_userinfo(access_token: str) -> dict:
    """Return the OIDC userinfo claims for the authenticated LinkedIn member."""
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.get(
            LINKEDIN_USERINFO_URL,
            headers={"Authorization": f"Bearer {access_token}"},
        )

    if response.status_code != 200:
        raise LinkedInOAuthError(f"userinfo fetch failed: HTTP {response.status_code}")

    claims = response.json()
    if not claims.get("sub"):
        raise LinkedInOAuthError("userinfo response had no sub")
    return claims


def map_userinfo_to_profile(claims: dict) -> dict:
    """Map OIDC userinfo claims to our stored profile shape.

    Keeps the same keys the simulated profile uses so downstream/UserOut stays
    uniform. OIDC does not expose employment data, so headline/company/title/
    tenure_years are null (unknown) rather than fabricated.
    """
    return {
        "sub": claims.get("sub"),
        "name": claims.get("name"),
        "headline": None,
        "company": None,
        "title": None,
        "tenure_years": None,
        "picture": claims.get("picture"),
        "email": claims.get("email"),
        "source": "linkedin_live",
    }
