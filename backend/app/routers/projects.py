"""F3 Project Card CRUD, screenshot uploads, and repo activity."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.models import Intent, ProjectCard, User
from app.db.session import get_db
from app.schemas.intent import IntentOut
from app.schemas.project import (
    ProjectCardOut,
    ProjectCreateIn,
    ProjectOwnerOut,
    ProjectUpdateIn,
    RepoActivityOut,
    ScreenshotKeyIn,
    ScreenshotOut,
    ScreenshotUrlIn,
)
from app.services import s3_service
from app.services.github_provider import fetch_repo_activity

router = APIRouter(prefix="/projects", tags=["projects"])


def _owner_out(owner: User) -> ProjectOwnerOut:
    avatar_url = owner.github_profile.get("avatar_url") if owner.github_profile else None
    return ProjectOwnerOut(
        id=owner.id,
        github_login=owner.github_login,
        avatar_url=avatar_url,
        primary_role=owner.primary_role,
    )


def _to_out(db: Session, card: ProjectCard) -> ProjectCardOut:
    """Assemble the full card contract: owner summary, the owner's current intent,
    and a presigned GET URL for each stored screenshot key."""
    owner = db.get(User, card.owner_id)
    intent = db.get(Intent, card.owner_id)
    screenshots = [
        ScreenshotOut(key=key, url=s3_service.presigned_get(key))
        for key in card.screenshot_s3_keys
    ]
    return ProjectCardOut(
        id=card.id,
        owner_id=card.owner_id,
        title=card.title,
        stage=card.stage,
        needs=card.needs,
        demo_url=card.demo_url,
        team_division=card.team_division,
        repo_full_names=list(card.repo_full_names),
        screenshots=screenshots,
        status=card.status,
        created_at=card.created_at,
        updated_at=card.updated_at,
        owner=_owner_out(owner),
        intent=IntentOut(intent_type=intent.intent_type, note=intent.note) if intent else None,
    )


def _get_card(db: Session, project_id: uuid.UUID) -> ProjectCard:
    card = db.get(ProjectCard, project_id)
    if card is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    return card


def _get_owned_card(db: Session, project_id: uuid.UUID, current_user: User) -> ProjectCard:
    card = _get_card(db, project_id)
    if card.owner_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not the project owner")
    return card


@router.post("", response_model=ProjectCardOut, status_code=status.HTTP_201_CREATED)
def create_project(
    payload: ProjectCreateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProjectCardOut:
    card = ProjectCard(
        owner_id=current_user.id,
        title=payload.title,
        stage=payload.stage,
        needs=payload.needs,
        demo_url=payload.demo_url,
        team_division=payload.team_division,
        repo_full_names=payload.repo_full_names,
        screenshot_s3_keys=[],
        status="active",
    )
    db.add(card)
    db.commit()
    db.refresh(card)
    return _to_out(db, card)


@router.get("", response_model=list[ProjectCardOut])
def list_projects(
    stage: str | None = Query(default=None),
    owner: str | None = Query(default=None, description="owner github_login or id"),
    q: str | None = Query(default=None, description="ILIKE match on title/needs"),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[ProjectCardOut]:
    """Discovery feed: only active cards, newest first."""
    stmt = select(ProjectCard).where(ProjectCard.status == "active")

    if stage is not None:
        stmt = stmt.where(ProjectCard.stage == stage)

    if owner is not None:
        owner_user = None
        try:
            owner_user = db.get(User, uuid.UUID(owner))
        except ValueError:
            owner_user = db.execute(
                select(User).where(User.github_login == owner)
            ).scalar_one_or_none()
        if owner_user is None:
            return []
        stmt = stmt.where(ProjectCard.owner_id == owner_user.id)

    if q:
        like = f"%{q}%"
        stmt = stmt.where(ProjectCard.title.ilike(like) | ProjectCard.needs.ilike(like))

    stmt = stmt.order_by(ProjectCard.created_at.desc()).limit(limit).offset(offset)
    cards = db.execute(stmt).scalars().all()
    return [_to_out(db, card) for card in cards]


@router.get("/mine", response_model=list[ProjectCardOut])
def list_my_projects(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[ProjectCardOut]:
    """The current user's cards, including archived, newest first."""
    stmt = (
        select(ProjectCard)
        .where(ProjectCard.owner_id == current_user.id)
        .order_by(ProjectCard.created_at.desc())
    )
    cards = db.execute(stmt).scalars().all()
    return [_to_out(db, card) for card in cards]


@router.get("/{project_id}", response_model=ProjectCardOut)
def get_project(project_id: uuid.UUID, db: Session = Depends(get_db)) -> ProjectCardOut:
    return _to_out(db, _get_card(db, project_id))


@router.patch("/{project_id}", response_model=ProjectCardOut)
def update_project(
    project_id: uuid.UUID,
    payload: ProjectUpdateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProjectCardOut:
    card = _get_owned_card(db, project_id, current_user)
    updates = payload.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(card, field, value)
    db.commit()
    db.refresh(card)
    return _to_out(db, card)


@router.delete("/{project_id}", response_model=ProjectCardOut)
def archive_project(
    project_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProjectCardOut:
    """Soft-delete: archive rather than hard-delete so the card survives."""
    card = _get_owned_card(db, project_id, current_user)
    card.status = "archived"
    db.commit()
    db.refresh(card)
    return _to_out(db, card)


@router.post("/{project_id}/screenshots-upload-url", status_code=status.HTTP_201_CREATED)
def create_screenshot_upload_url(
    project_id: uuid.UUID,
    payload: ScreenshotUrlIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    card = _get_owned_card(db, project_id, current_user)
    key = s3_service.screenshot_key(card.id, payload.content_type)
    upload_url = s3_service.presigned_put(key, payload.content_type)
    return {"upload_url": upload_url, "key": key}


@router.post("/{project_id}/screenshots", response_model=ProjectCardOut)
def add_screenshot(
    project_id: uuid.UUID,
    payload: ScreenshotKeyIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProjectCardOut:
    card = _get_owned_card(db, project_id, current_user)
    if not payload.key.startswith(f"screenshots/{card.id}/"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not a screenshot key for this project",
        )
    if not s3_service.object_exists(payload.key):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Object not uploaded to S3 yet",
        )
    if payload.key not in card.screenshot_s3_keys:
        # Reassign (not .append) so SQLAlchemy tracks the ARRAY mutation.
        card.screenshot_s3_keys = [*card.screenshot_s3_keys, payload.key]
        db.commit()
        db.refresh(card)
    return _to_out(db, card)


@router.delete("/{project_id}/screenshots", response_model=ProjectCardOut)
def remove_screenshot(
    project_id: uuid.UUID,
    payload: ScreenshotKeyIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProjectCardOut:
    card = _get_owned_card(db, project_id, current_user)
    if payload.key in card.screenshot_s3_keys:
        card.screenshot_s3_keys = [k for k in card.screenshot_s3_keys if k != payload.key]
        db.commit()
        db.refresh(card)
        try:
            s3_service.delete_object(payload.key)
        except Exception:
            # Best-effort: the key is already gone from the card either way.
            pass
    return _to_out(db, card)


@router.get("/{project_id}/repo-activity", response_model=list[RepoActivityOut])
def repo_activity(project_id: uuid.UUID, db: Session = Depends(get_db)) -> list[RepoActivityOut]:
    card = _get_card(db, project_id)
    return [RepoActivityOut(**fetch_repo_activity(full_name)) for full_name in card.repo_full_names]
