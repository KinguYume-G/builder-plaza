import uuid
from urllib.parse import urlencode

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import get_current_user
from app.db.models import User
from app.db.session import get_db
from app.schemas.auth import DevLoginIn, TokenOut
from app.schemas.trust import (
    GithubConnectIn,
    GithubConnectOut,
    GithubSummary,
    LinkedInBindIn,
    LinkedInProfileOut,
)
from app.schemas.user import UserOut
from app.services import completeness, github_oauth, linkedin_oauth
from app.services.auth_service import issue_token, upsert_github_profile, upsert_user
from app.services.github_provider import GitHubAPIError, GitHubDev, GitHubUserNotFound
from app.services.identity_provider import get_identity_provider

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/dev-login", response_model=TokenOut)
def dev_login(payload: DevLoginIn, db: Session = Depends(get_db)) -> TokenOut:
    # Local-only shortcut: mints a token without the real GitHub OAuth flow.
    if settings.environment != "local":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="dev-login is only available in the local environment",
        )

    # Onboard the demo user outright so dev-login lands straight on home.
    user = upsert_user(
        db,
        github_login=payload.github_login,
        primary_role=payload.primary_role,
        onboarding_complete=True,
    )
    return TokenOut(access_token=issue_token(user), user=UserOut.from_user(user))


@router.post("/github/connect", response_model=GithubConnectOut)
def github_connect(payload: GithubConnectIn, db: Session = Depends(get_db)) -> GithubConnectOut:
    """Connect GitHub by public username (F1): fetch REAL public data, cache the
    summary onto the user, and mint our JWT."""
    try:
        summary = GitHubDev().fetch(payload.github_login)
    except GitHubUserNotFound:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"GitHub user '{payload.github_login}' not found",
        )
    except GitHubAPIError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"GitHub API error: {exc}",
        )

    user = upsert_github_profile(db, github_login=summary["login"], github_profile=summary)
    return GithubConnectOut(
        access_token=issue_token(user),
        user=UserOut.from_user(user),
        github=GithubSummary.model_validate(summary),
    )


@router.get("/linkedin/profiles", response_model=list[LinkedInProfileOut])
def linkedin_profiles() -> list[LinkedInProfileOut]:
    """List the selectable LinkedIn identities for the consent screen (ADR-0003)."""
    provider = get_identity_provider()
    return [LinkedInProfileOut.model_validate(p) for p in provider.list_profiles()]


@router.post("/linkedin/bind", response_model=UserOut)
def linkedin_bind(
    payload: LinkedInBindIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserOut:
    """Bind a LinkedIn identity to the current user (F1)."""
    provider = get_identity_provider()
    profile = provider.get_profile(payload.profile_id)
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"LinkedIn profile '{payload.profile_id}' not found",
        )

    sub = profile["sub"]
    existing = (
        db.query(User).filter(User.linkedin_sub == sub, User.id != current_user.id).first()
    )
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This LinkedIn identity is already bound to another user",
        )

    current_user.linkedin_sub = sub
    current_user.linkedin_profile = profile
    completeness.compute(current_user)
    db.commit()
    db.refresh(current_user)
    return UserOut.from_user(current_user)


@router.get("/linkedin/mode")
def linkedin_mode() -> dict:
    """Report which LinkedIn implementation is active (ADR-0003). Public: the
    client uses it to decide between the simulated consent screen and the real
    OIDC redirect."""
    return {"mode": settings.linkedin_mode}


@router.get("/linkedin/login")
def linkedin_login(current_user: User = Depends(get_current_user)) -> dict:
    """Kick off the real LinkedIn OIDC flow: return the authorize URL the client
    should send the browser to. The signed state carries the current user's id so
    the callback knows who to bind."""
    state = linkedin_oauth.create_state_token(current_user.id)
    return {"authorize_url": linkedin_oauth.build_authorize_url(state)}


@router.get("/linkedin/callback")
async def linkedin_callback(
    code: str | None = Query(default=None),
    state: str | None = Query(default=None),
    error: str | None = Query(default=None),
    error_description: str | None = Query(default=None),
    db: Session = Depends(get_db),
) -> RedirectResponse:
    """LinkedIn redirects here after consent. Verify state, exchange the code,
    fetch OIDC userinfo, and bind the identity to the user who started the flow.

    All failure paths 302 back to the frontend with a ``linkedin=<status>`` flag
    rather than surfacing an error page, so an interrupted flow can be retried
    without leaving a half-baked account (F1)."""
    error_redirect = RedirectResponse(
        f"{settings.frontend_url}/#/onboarding/linkedin?linkedin=error", status_code=302
    )

    if error or not code or not state:
        return error_redirect

    user_id = linkedin_oauth.verify_state_token(state)
    if user_id is None:
        return error_redirect

    try:
        user_uuid = uuid.UUID(user_id)
    except ValueError:
        return error_redirect

    user = db.get(User, user_uuid)
    if user is None:
        return error_redirect

    try:
        access_token = await linkedin_oauth.exchange_code_for_token(code)
        claims = await linkedin_oauth.fetch_userinfo(access_token)
    except linkedin_oauth.LinkedInOAuthError:
        return error_redirect

    sub = claims["sub"]
    existing = db.query(User).filter(User.linkedin_sub == sub, User.id != user.id).first()
    if existing is not None:
        return RedirectResponse(
            f"{settings.frontend_url}/#/onboarding/linkedin?linkedin=conflict",
            status_code=302,
        )

    user.linkedin_sub = sub
    user.linkedin_profile = linkedin_oauth.map_userinfo_to_profile(claims)
    completeness.compute(user)
    db.commit()

    return RedirectResponse(
        f"{settings.frontend_url}/#/onboarding/role?linkedin=ok", status_code=302
    )


@router.get("/github/login")
def github_login() -> RedirectResponse:
    """Kick off the GitHub OAuth flow: redirect the browser to GitHub's consent screen."""
    if not settings.github_client_id:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="GitHub OAuth is not configured",
        )

    state = github_oauth.create_state_token()
    return RedirectResponse(github_oauth.build_authorize_url(state))


@router.get("/github/callback")
async def github_callback(
    code: str = Query(...),
    state: str = Query(...),
    db: Session = Depends(get_db),
) -> RedirectResponse:
    """GitHub redirects here with ?code&state. Verify, mint our JWT, bounce to the frontend.

    A failed or interrupted flow never creates a half-baked account: the user
    row is only written after the token exchange and profile fetch both succeed
    (F1: "绑定失败/中断可安全重试,不产生半成品账号").
    """
    if not github_oauth.verify_state_token(state):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="invalid or expired OAuth state",
        )

    try:
        access_token = await github_oauth.exchange_code_for_token(code)
        github_login = await github_oauth.fetch_github_login(access_token)
    except github_oauth.GitHubOAuthError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"GitHub OAuth failed: {exc}",
        )

    # New users default to "builder"; the onboarding flow (LinkedIn bind + role
    # pick, per F1) can update it before the profile is unlocked.
    user = upsert_user(db, github_login=github_login, primary_role="builder")
    token = issue_token(user)

    query = urlencode({"token": token})
    return RedirectResponse(f"{settings.frontend_url}/auth/callback?{query}")
