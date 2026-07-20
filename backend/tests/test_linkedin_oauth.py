from urllib.parse import parse_qs, urlparse

from app.core.config import settings
from app.services import linkedin_oauth

# Pure unit coverage of the live LinkedIn OIDC helpers: authorize-URL build,
# state signing round-trip, and userinfo -> profile mapping. The token exchange
# and userinfo fetch (which hit LinkedIn) are not covered here.


def test_build_authorize_url_carries_oidc_params() -> None:
    url = linkedin_oauth.build_authorize_url("some-state")
    query = parse_qs(urlparse(url).query)

    assert url.startswith(linkedin_oauth.LINKEDIN_AUTHORIZE_URL)
    assert query["response_type"] == ["code"]
    assert query["client_id"] == [settings.linkedin_client_id]
    assert query["redirect_uri"] == [settings.linkedin_redirect_uri]
    assert query["scope"] == ["openid profile email"]
    assert query["state"] == ["some-state"]
    # url-encoded scope: spaces become +
    assert "scope=openid+profile+email" in url


def test_state_token_round_trip() -> None:
    state = linkedin_oauth.create_state_token("user-123")

    assert linkedin_oauth.verify_state_token(state) == "user-123"


def test_verify_rejects_tampered_state() -> None:
    state = linkedin_oauth.create_state_token("user-123")

    assert linkedin_oauth.verify_state_token(state + "tamper") is None
    assert linkedin_oauth.verify_state_token("not-a-real-token") is None


def test_verify_rejects_expired_state() -> None:
    from datetime import datetime, timedelta, timezone

    import jwt

    from app.core.security import ALGORITHM

    expired = jwt.encode(
        {
            "mark": "linkedin_oauth_state",
            "sub": "user-123",
            "exp": datetime.now(timezone.utc) - timedelta(minutes=1),
        },
        settings.jwt_secret,
        algorithm=ALGORITHM,
    )

    assert linkedin_oauth.verify_state_token(expired) is None


def test_verify_rejects_wrong_marker() -> None:
    import jwt

    from app.core.security import ALGORITHM

    wrong = jwt.encode(
        {"mark": "github_oauth_state", "sub": "user-123"},
        settings.jwt_secret,
        algorithm=ALGORITHM,
    )

    assert linkedin_oauth.verify_state_token(wrong) is None


def test_map_userinfo_maps_identity_and_nulls_employment() -> None:
    claims = {
        "sub": "linkedin|abc123",
        "name": "Jordan Ng",
        "given_name": "Jordan",
        "family_name": "Ng",
        "picture": "https://media.licdn.com/pic.jpg",
        "email": "jordan@example.com",
        "email_verified": True,
        "locale": "en-US",
    }

    profile = linkedin_oauth.map_userinfo_to_profile(claims)

    assert profile["sub"] == "linkedin|abc123"
    assert profile["name"] == "Jordan Ng"
    assert profile["picture"] == "https://media.licdn.com/pic.jpg"
    assert profile["email"] == "jordan@example.com"
    assert profile["source"] == "linkedin_live"
    # OIDC exposes no employment data -> these stay null, never fabricated.
    assert profile["headline"] is None
    assert profile["company"] is None
    assert profile["title"] is None
    assert profile["tenure_years"] is None
