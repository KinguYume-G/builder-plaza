import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.models import User
from app.db.session import get_db
from app.schemas.trust import GithubSummary, RoleIn
from app.schemas.user import UserOut
from app.services import completeness, s3_service

router = APIRouter(tags=["me"])


class AvatarUrlIn(BaseModel):
    content_type: str


class AvatarKeyIn(BaseModel):
    key: str


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


@router.post("/me/avatar-upload-url", status_code=status.HTTP_201_CREATED)
def create_avatar_upload_url(
    payload: AvatarUrlIn,
    current_user: User = Depends(get_current_user),
) -> dict:
    """F2: presigned PUT for the profile avatar (same S3 flow as screenshots)."""
    ext = s3_service.ext_for_content_type(payload.content_type)
    if ext is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="content_type must be image/jpeg, image/png or image/webp",
        )
    key = f"avatars/{current_user.id}/{uuid.uuid4()}.{ext}"
    return {
        "upload_url": s3_service.presigned_put(key, payload.content_type),
        "key": key,
    }


@router.post("/me/avatar", response_model=UserOut)
def set_avatar(
    payload: AvatarKeyIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserOut:
    if not payload.key.startswith(f"avatars/{current_user.id}/"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Not your avatar key"
        )
    if not s3_service.object_exists(payload.key):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Object not uploaded to S3 yet",
        )
    old_key = current_user.avatar_s3_key
    current_user.avatar_s3_key = payload.key
    db.commit()
    db.refresh(current_user)
    if old_key and old_key != payload.key:
        try:
            s3_service.delete_object(old_key)
        except Exception:
            pass  # best-effort cleanup
    return UserOut.from_user(current_user)


@router.delete("/me/avatar", response_model=UserOut)
def clear_avatar(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserOut:
    old_key = current_user.avatar_s3_key
    current_user.avatar_s3_key = None
    db.commit()
    db.refresh(current_user)
    if old_key:
        try:
            s3_service.delete_object(old_key)
        except Exception:
            pass
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
