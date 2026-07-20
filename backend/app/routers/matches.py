"""F5 matching endpoints: the match list, dismiss, and the plain-language
credibility summary."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.models import PeerReview, User
from app.db.session import get_db
from app.schemas.match import CredibilitySummaryOut, MatchCandidateOut, MatchOut
from app.services import activity_service
from app.services.matching import engine
from app.services.matching.credibility import credibility_summary

router = APIRouter(tags=["matches"])


def _match_out(db: Session, match) -> MatchOut:
    candidate = db.get(User, match.candidate)
    profile = candidate.github_profile or {}
    linkedin = candidate.linkedin_profile or {}
    return MatchOut(
        id=match.id,
        candidate=MatchCandidateOut(
            id=candidate.id,
            github_login=candidate.github_login,
            avatar_url=profile.get("avatar_url"),
            primary_role=candidate.primary_role,
            trust_score=float(candidate.trust_score or 0),
            headline=linkedin.get("headline"),
        ),
        score=float(match.score),
        exploratory=match.exploratory,
        match_reason=match.match_reason,
        state=match.state,
        created_at=match.created_at,
    )


@router.get("/matches", response_model=list[MatchOut])
def list_matches(
    refresh: bool = Query(default=True, description="re-run the engine before listing"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[MatchOut]:
    """The current user's match round. With refresh=true (default) the full
    pipeline runs: embed -> recall -> GPR -> epsilon-greedy -> reasons."""
    if refresh:
        matches = engine.refresh_matches(db, current_user)
    else:
        from app.db.models import Match

        matches = (
            db.execute(
                select(Match)
                .where(Match.for_user == current_user.id, Match.state == "active")
                .order_by(Match.score.desc())
            )
            .scalars()
            .all()
        )
    return [_match_out(db, match) for match in matches]


@router.post("/matches/{match_id}/dismiss", response_model=MatchOut)
def dismiss(
    match_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MatchOut:
    match = engine.dismiss_match(db, current_user, match_id)
    if match is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Match not found")
    return _match_out(db, match)


@router.get("/users/{user_id}/credibility-summary", response_model=CredibilitySummaryOut)
def credibility(
    user_id: uuid.UUID,
    _viewer: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CredibilitySummaryOut:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    events = activity_service.get_user_events(db, user)
    weekly = activity_service.weekly_activity(events)
    avg_stars, review_count = db.execute(
        select(func.avg(PeerReview.stars), func.count(PeerReview.id)).where(
            PeerReview.reviewee == user.id
        )
    ).one()

    summary, highlights = credibility_summary(
        github_login=user.github_login,
        primary_role=user.primary_role,
        github_summary=user.github_profile,
        active_weeks=sum(1 for bucket in weekly if bucket["count"] > 0),
        total_weeks=len(weekly),
        linkedin_profile=user.linkedin_profile,
        avg_stars=float(avg_stars) if avg_stars is not None else None,
        review_count=review_count,
    )
    return CredibilitySummaryOut(
        user_id=user.id,
        github_login=user.github_login,
        summary=summary,
        highlights=highlights,
    )
