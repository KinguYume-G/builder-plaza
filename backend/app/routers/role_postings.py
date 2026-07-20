"""F8 Request Market: role postings CRUD.

Applying to a posting reuses the F7 pipeline: the client sends a collab
request to the posting owner with ``context_ref`` = posting id, so applications
inherit the same structured-pitch + accept-gated-conversation flow.
"""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.models import ProjectCard, RolePosting, User
from app.db.session import get_db
from app.schemas.role_posting import (
    PostingOwnerOut,
    PostingRepoOut,
    RolePostingIn,
    RolePostingOut,
    RolePostingUpdateIn,
)
from app.services.github_provider import fetch_repo_activity

router = APIRouter(prefix="/role-postings", tags=["role-postings"])


def _posting_out(db: Session, posting: RolePosting, with_repos: bool = False) -> RolePostingOut:
    owner = db.get(User, posting.owner_id)
    profile = owner.github_profile or {}
    project = db.get(ProjectCard, posting.project_id) if posting.project_id else None

    repos: list[PostingRepoOut] = []
    if with_repos and project is not None:
        # Real GitHub activity for the linked repos (graceful per-repo errors).
        for full_name in project.repo_full_names:
            repos.append(PostingRepoOut(**fetch_repo_activity(full_name)))

    return RolePostingOut(
        id=posting.id,
        posting_type=posting.posting_type,
        role_desc=posting.role_desc,
        skills=list(posting.skills),
        project_id=posting.project_id,
        project_title=project.title if project else None,
        stage=posting.stage,
        tech_stack=posting.tech_stack,
        commitment=posting.commitment,
        access_tier=posting.access_tier,
        status=posting.status,
        owner=PostingOwnerOut(
            id=owner.id,
            github_login=owner.github_login,
            avatar_url=profile.get("avatar_url"),
            primary_role=owner.primary_role,
            trust_score=float(owner.trust_score or 0),
        ),
        repos=repos,
        created_at=posting.created_at,
        updated_at=posting.updated_at,
    )


@router.post("", response_model=RolePostingOut, status_code=status.HTTP_201_CREATED)
def create_posting(
    payload: RolePostingIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> RolePostingOut:
    if payload.posting_type == "maintainer":
        project = db.get(ProjectCard, payload.project_id)
        if project is None or project.owner_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Maintainer postings must link one of YOUR projects",
            )
        if not project.repo_full_names:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="The linked project has no verified repositories",
            )

    posting = RolePosting(
        owner_id=current_user.id,
        project_id=payload.project_id,
        posting_type=payload.posting_type,
        role_desc=payload.role_desc,
        skills=payload.skills,
        stage=payload.stage,
        tech_stack=payload.tech_stack,
        commitment=payload.commitment,
        access_tier=payload.access_tier,
        status="open",
    )
    db.add(posting)
    db.commit()
    db.refresh(posting)
    return _posting_out(db, posting)


@router.get("", response_model=list[RolePostingOut])
def list_postings(
    posting_type: str | None = Query(default=None),
    skill: str | None = Query(default=None, description="case-insensitive skill filter"),
    mine: bool = Query(default=False),
    limit: int = Query(default=30, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[RolePostingOut]:
    stmt = select(RolePosting)
    if mine:
        stmt = stmt.where(RolePosting.owner_id == current_user.id)
    else:
        stmt = stmt.where(RolePosting.status == "open")
    if posting_type is not None:
        stmt = stmt.where(RolePosting.posting_type == posting_type)
    stmt = stmt.order_by(RolePosting.created_at.desc()).limit(limit).offset(offset)
    postings = db.execute(stmt).scalars().all()
    if skill:
        lowered = skill.lower()
        postings = [
            posting
            for posting in postings
            if any(lowered in entry.lower() for entry in posting.skills)
        ]
    return [_posting_out(db, posting) for posting in postings]


@router.get("/{posting_id}", response_model=RolePostingOut)
def get_posting(
    posting_id: uuid.UUID,
    _viewer: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> RolePostingOut:
    posting = db.get(RolePosting, posting_id)
    if posting is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Posting not found")
    return _posting_out(db, posting, with_repos=True)


@router.patch("/{posting_id}", response_model=RolePostingOut)
def update_posting(
    posting_id: uuid.UUID,
    payload: RolePostingUpdateIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> RolePostingOut:
    posting = db.get(RolePosting, posting_id)
    if posting is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Posting not found")
    if posting.owner_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your posting")
    updates = payload.model_dump(exclude_unset=True)
    if updates.get("status") not in (None, "open", "closed"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="status must be open|closed"
        )
    for field, value in updates.items():
        setattr(posting, field, value)
    db.commit()
    db.refresh(posting)
    return _posting_out(db, posting)


@router.delete("/{posting_id}", response_model=RolePostingOut)
def close_posting(
    posting_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> RolePostingOut:
    """Soft-close (postings stay for the record, like archived projects)."""
    posting = db.get(RolePosting, posting_id)
    if posting is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Posting not found")
    if posting.owner_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not your posting")
    posting.status = "closed"
    db.commit()
    db.refresh(posting)
    return _posting_out(db, posting)
