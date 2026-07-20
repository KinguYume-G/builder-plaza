from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.security import create_access_token
from app.db.models import User
from app.services import completeness


def get_user_by_github_login(db: Session, github_login: str) -> User | None:
    # Case-insensitive: GitHub logins are case-insensitive, so a differently
    # cased login must resolve to the SAME user row (belt-and-suspenders on top
    # of storing the canonical casing at connect time).
    return db.execute(
        select(User).where(func.lower(User.github_login) == github_login.lower())
    ).scalar_one_or_none()


def upsert_user(
    db: Session, github_login: str, primary_role: str, onboarding_complete: bool = False
) -> User:
    """Fetch the user by github_login, or create a fresh one. Commits."""
    user = get_user_by_github_login(db, github_login)

    if user is None:
        user = User(
            github_login=github_login,
            primary_role=primary_role,
            completeness_pct=0,
            trust_score=0,
            reverify_flag=False,
            onboarding_complete=onboarding_complete,
        )
        db.add(user)
    elif onboarding_complete:
        user.onboarding_complete = True

    db.commit()
    db.refresh(user)
    return user


def upsert_github_profile(db: Session, github_login: str, github_profile: dict) -> User:
    """Connect GitHub (F1): upsert by login, cache the fetched summary, recompute
    completeness. New rows default to the "builder" role and stay
    onboarding-incomplete until LinkedIn is bound and a role is picked. Commits.
    """
    user = get_user_by_github_login(db, github_login)

    if user is None:
        user = User(
            github_login=github_login,
            primary_role="builder",
            completeness_pct=0,
            trust_score=0,
            reverify_flag=False,
            onboarding_complete=False,
        )
        db.add(user)

    user.github_profile = github_profile
    completeness.compute(user)

    db.commit()
    db.refresh(user)
    return user


def issue_token(user: User) -> str:
    return create_access_token(str(user.id))
