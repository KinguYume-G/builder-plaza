"""F10 user-facing evidence endpoints: Verified Activity + Ownership Evidence."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.models import User
from app.db.session import get_db
from app.schemas.activity import (
    ActivityEventOut,
    ActivityTimelineOut,
    OwnershipEvidenceOut,
    RepoRoleOut,
    WeeklyActivityOut,
)
from app.db.models import CollabRequest, PeerReview
from app.schemas.trust_score import (
    PeerReviewIn,
    PeerReviewOut,
    TrustScoreOut,
)
from app.services import activity_service, trust_service

router = APIRouter(prefix="/users", tags=["users"])


def _get_user(db: Session, user_id: uuid.UUID) -> User:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


@router.get("/{user_id}/activity-timeline", response_model=ActivityTimelineOut)
def activity_timeline(
    user_id: uuid.UUID,
    _viewer: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ActivityTimelineOut:
    """Verified Activity: the user's recent public GitHub events, newest first.

    "Verified" because every entry comes straight from GitHub's public event
    feed for the connected account -- nothing is self-reported.
    """
    user = _get_user(db, user_id)
    events = activity_service.get_user_events(db, user)
    return ActivityTimelineOut(
        user_id=user.id,
        github_login=user.github_login,
        events=[ActivityEventOut(**event) for event in events],
        fetched_at=user.github_events_fetched_at,
    )


@router.get("/{user_id}/ownership-evidence", response_model=OwnershipEvidenceOut)
def ownership_evidence(
    user_id: uuid.UUID,
    _viewer: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> OwnershipEvidenceOut:
    """Ownership Evidence: a 12-week activity continuity series plus the roles
    the user actually holds on their repositories."""
    user = _get_user(db, user_id)
    events = activity_service.get_user_events(db, user)
    weekly = activity_service.weekly_activity(events)
    repo_roles = activity_service.fetch_repo_roles(user.github_login)
    return OwnershipEvidenceOut(
        user_id=user.id,
        github_login=user.github_login,
        weekly_activity=[WeeklyActivityOut(**bucket) for bucket in weekly],
        active_weeks=sum(1 for bucket in weekly if bucket["count"] > 0),
        total_weeks=len(weekly),
        repo_roles=[RepoRoleOut(**entry) for entry in repo_roles],
    )


@router.get("/{user_id}/trust-score", response_model=TrustScoreOut)
def trust_score(
    user_id: uuid.UUID,
    _viewer: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> TrustScoreOut:
    """F6: the full trust-score breakdown. Recomputes (and persists
    users.trust_score) on every read so the number is never stale."""
    user = _get_user(db, user_id)
    return TrustScoreOut(**trust_service.compute_trust(db, user))


def _review_out(db: Session, review: PeerReview) -> PeerReviewOut:
    reviewer = db.get(User, review.reviewer)
    return PeerReviewOut(
        id=review.id,
        reviewer_id=review.reviewer,
        reviewer_login=reviewer.github_login if reviewer else "",
        reviewee_id=review.reviewee,
        stars=review.stars,
        tags=list(review.tags),
        created_at=review.created_at,
    )


@router.get("/{user_id}/reviews", response_model=list[PeerReviewOut])
def list_reviews(
    user_id: uuid.UUID,
    _viewer: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[PeerReviewOut]:
    user = _get_user(db, user_id)
    reviews = (
        db.execute(
            select(PeerReview)
            .where(PeerReview.reviewee == user.id)
            .order_by(PeerReview.created_at.desc())
        )
        .scalars()
        .all()
    )
    return [_review_out(db, review) for review in reviews]


@router.post(
    "/{user_id}/reviews", response_model=PeerReviewOut, status_code=status.HTTP_201_CREATED
)
def create_review(
    user_id: uuid.UUID,
    payload: PeerReviewIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PeerReviewOut:
    """F6: peer review, unlocked only by a real collaboration (the referenced
    collab request must be ACCEPTED and involve both parties)."""
    reviewee = _get_user(db, user_id)
    if reviewee.id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="You cannot review yourself"
        )

    request = db.get(CollabRequest, payload.collab_request_id)
    if request is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Collaboration request not found"
        )
    if request.state != "accepted":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Reviews unlock after a collaboration request is accepted",
        )
    participants = {request.from_user, request.to_user}
    if participants != {current_user.id, reviewee.id}:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only review your counterpart on that collaboration",
        )

    existing = db.execute(
        select(PeerReview).where(
            PeerReview.collab_request == request.id,
            PeerReview.reviewer == current_user.id,
        )
    ).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You already reviewed this collaboration",
        )

    review = PeerReview(
        reviewer=current_user.id,
        reviewee=reviewee.id,
        collab_request=request.id,
        stars=payload.stars,
        tags=payload.tags,
    )
    db.add(review)
    db.commit()
    db.refresh(review)
    return _review_out(db, review)
