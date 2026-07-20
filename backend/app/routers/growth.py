"""F4 Growth Plaza: manual refresh, the plaza feed, and the scheduled-refresh
hook EventBridge calls daily in production."""

import uuid

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from app.core.config import settings
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.models import GrowthPost, ProjectCard, User
from app.db.session import get_db
from app.schemas.growth import GrowthPostOut, PlazaItemOut, RefreshGrowthOut
from app.schemas.project import ProjectOwnerOut
from app.services import growth_service

router = APIRouter(tags=["growth"])


def _post_out(post: GrowthPost) -> GrowthPostOut:
    return GrowthPostOut(
        id=post.id,
        project_id=post.project_id,
        summary=post.summary,
        source_events=list(post.source_events or []),
        trigger=post.trigger,
        created_at=post.created_at,
    )


@router.post("/projects/{project_id}/refresh-growth", response_model=RefreshGrowthOut)
def refresh_growth(
    project_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> RefreshGrowthOut:
    card = db.get(ProjectCard, project_id)
    if card is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    if card.owner_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not the project owner")
    if not card.repo_full_names:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Project has no linked repositories to poll",
        )
    post = growth_service.refresh_growth(db, card, trigger="manual")
    return RefreshGrowthOut(refreshed=post is not None, post=_post_out(post) if post else None)


@router.get("/projects/{project_id}/growth", response_model=list[GrowthPostOut])
def project_growth(
    project_id: uuid.UUID,
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
) -> list[GrowthPostOut]:
    """A single project's growth history, newest first (project detail tab)."""
    if db.get(ProjectCard, project_id) is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")
    posts = (
        db.execute(
            select(GrowthPost)
            .where(GrowthPost.project_id == project_id)
            .order_by(GrowthPost.created_at.desc())
            .limit(limit)
        )
        .scalars()
        .all()
    )
    return [_post_out(post) for post in posts]


@router.post("/internal/growth-refresh-all")
def growth_refresh_all(
    x_internal_token: str = Header(default=""),
    db: Session = Depends(get_db),
) -> dict:
    """Scheduled path (EventBridge daily, ADR-0002). Guarded by a shared
    secret header, not user JWTs; disabled when no token is configured."""
    if not settings.internal_task_token or x_internal_token != settings.internal_task_token:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
    written = growth_service.refresh_all_active(db)
    return {"refreshed_projects": written}


@router.get("/plaza", response_model=list[PlazaItemOut])
def plaza(
    role: str | None = Query(default=None, description="owner primary_role filter"),
    stage: str | None = Query(default=None, description="project stage filter"),
    limit: int = Query(default=30, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> list[PlazaItemOut]:
    """The plaza feed: growth posts across all ACTIVE projects, newest first."""
    stmt = (
        select(GrowthPost, ProjectCard, User)
        .join(ProjectCard, GrowthPost.project_id == ProjectCard.id)
        .join(User, ProjectCard.owner_id == User.id)
        .where(ProjectCard.status == "active")
    )
    if role is not None:
        stmt = stmt.where(User.primary_role == role)
    if stage is not None:
        stmt = stmt.where(ProjectCard.stage == stage)
    stmt = stmt.order_by(GrowthPost.created_at.desc()).limit(limit).offset(offset)

    items = []
    for post, card, owner in db.execute(stmt).all():
        avatar_url = owner.github_profile.get("avatar_url") if owner.github_profile else None
        items.append(
            PlazaItemOut(
                post=_post_out(post),
                project_title=card.title,
                project_stage=card.stage,
                owner=ProjectOwnerOut(
                    id=owner.id,
                    github_login=owner.github_login,
                    avatar_url=avatar_url,
                    primary_role=owner.primary_role,
                ),
            )
        )
    return items
