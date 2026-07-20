from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.models import User
from app.db.session import get_db
from app.schemas.trust import GithubSummary, RoleIn
from app.schemas.user import UserOut
from app.services import completeness

router = APIRouter(tags=["me"])


@router.get("/me", response_model=UserOut)
def read_me(current_user: User = Depends(get_current_user)) -> UserOut:
    return UserOut.from_user(current_user)


@router.post("/me/role", response_model=UserOut)
def set_role(
    payload: RoleIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserOut:
    """Pick the primary role (F1). With LinkedIn already bound, this is the last
    onboarding step, so it flips onboarding_complete on."""
    current_user.primary_role = payload.primary_role
    if current_user.linkedin_sub is not None:
        current_user.onboarding_complete = True
    completeness.compute(current_user)
    db.commit()
    db.refresh(current_user)
    return UserOut.from_user(current_user)


@router.get("/me/github-summary", response_model=GithubSummary)
def read_github_summary(current_user: User = Depends(get_current_user)) -> GithubSummary:
    """Return the cached GitHub summary from the last connect (F1)."""
    if current_user.github_profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No GitHub profile connected",
        )
    return GithubSummary.model_validate(current_user.github_profile)
