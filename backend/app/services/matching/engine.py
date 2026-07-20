"""F5 engine orchestration (ADR-0001):

  embed -> pgvector cosine recall (top-20) -> GPR scoring -> epsilon-greedy
  exploration slot -> Match Reason -> persisted ``matches`` rows.

Recall runs in SQL against skill_embeddings (cosine distance); everything
downstream works on plain Python values so it stays testable. Dismissed
matches are excluded from future rounds.
"""

import random
import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import Intent, Match, SkillEmbedding, User
from app.services.matching import scoring
from app.services.matching.embeddings import upsert_user_embedding
from app.services.matching.skill_text import skill_terms

RECALL_K = 20
RESULT_N = 10


def _shared_terms(user: User, candidate: User) -> list[str]:
    """Case-insensitive overlap of skill terms, preserving candidate casing."""
    mine = {term.lower() for term in skill_terms(user)}
    seen: set[str] = set()
    shared = []
    for term in skill_terms(candidate):
        lowered = term.lower()
        if lowered in mine and lowered not in seen:
            seen.add(lowered)
            shared.append(term)
    return shared


def _intent_open(intent: Intent | None) -> bool:
    return intent is None or intent.intent_type != "not_open"


def recall_candidates(db: Session, user: User, k: int = RECALL_K) -> list[tuple[User, float]]:
    """Top-k users by cosine similarity of skill embeddings (excluding self and
    previously dismissed candidates)."""
    my_embedding = db.execute(
        select(SkillEmbedding).where(SkillEmbedding.user_id == user.id)
    ).scalar_one_or_none()
    if my_embedding is None:
        return []

    dismissed = (
        select(Match.candidate)
        .where(Match.for_user == user.id, Match.state == "dismissed")
        .scalar_subquery()
    )
    distance = SkillEmbedding.embedding.cosine_distance(my_embedding.embedding)
    rows = db.execute(
        select(User, distance.label("distance"))
        .join(SkillEmbedding, SkillEmbedding.user_id == User.id)
        .where(
            User.id != user.id,
            User.onboarding_complete.is_(True),
            User.id.notin_(dismissed),
        )
        .order_by(distance.asc())
        .limit(k)
    ).all()
    return [(candidate, 1.0 - float(dist)) for candidate, dist in rows]


def refresh_matches(
    db: Session, user: User, rng: random.Random | None = None
) -> list[Match]:
    """Run the full pipeline for one user and persist the round's matches."""
    rng = rng or random.Random()
    upsert_user_embedding(db, user)

    # Make sure every candidate with a profile has an embedding (demo scale).
    candidates_missing = db.execute(
        select(User)
        .outerjoin(SkillEmbedding, SkillEmbedding.user_id == User.id)
        .where(
            SkillEmbedding.id.is_(None),
            User.id != user.id,
            User.onboarding_complete.is_(True),
        )
    ).scalars().all()
    for candidate in candidates_missing:
        upsert_user_embedding(db, candidate)

    recalled = recall_candidates(db, user)
    if not recalled:
        return []

    intents = {
        intent.user_id: intent
        for intent in db.execute(
            select(Intent).where(Intent.user_id.in_([c.id for c, _sim in recalled]))
        ).scalars()
    }

    features = [
        scoring.pair_features(
            cosine_sim=similarity,
            candidate_trust=float(candidate.trust_score or 0),
            role_a=user.primary_role,
            role_b=candidate.primary_role,
            intent_open=_intent_open(intents.get(candidate.id)),
        )
        for candidate, similarity in recalled
    ]
    scores = scoring.score_pairs(features)
    ranked = sorted(
        zip((candidate for candidate, _sim in recalled), scores),
        key=lambda pair: -pair[1],
    )

    top = ranked[:RESULT_N]
    beyond = ranked[RESULT_N:]
    exploration_index = scoring.pick_exploration_slot(len(top), len(beyond), rng)
    if exploration_index is not None:
        # Replace the last top slot with the exploration pick.
        top = top[:-1] + [beyond[exploration_index]]

    result: list[Match] = []
    for position, (candidate, score) in enumerate(top):
        exploratory = exploration_index is not None and position == len(top) - 1
        reason = scoring.match_reason(
            _shared_terms(user, candidate),
            user.primary_role,
            candidate.primary_role,
            exploratory,
        )
        match = db.execute(
            select(Match).where(Match.for_user == user.id, Match.candidate == candidate.id)
        ).scalar_one_or_none()
        if match is None:
            match = Match(for_user=user.id, candidate=candidate.id)
            db.add(match)
        elif match.state == "dismissed":
            continue  # never resurface a dismissed candidate
        match.score = round(score, 4)
        match.exploratory = exploratory
        match.match_reason = reason
        match.state = "active"
        result.append(match)
    db.commit()
    for match in result:
        db.refresh(match)
    result.sort(key=lambda match: -float(match.score))
    return result


def dismiss_match(db: Session, user: User, match_id: uuid.UUID) -> Match | None:
    match = db.get(Match, match_id)
    if match is None or match.for_user != user.id:
        return None
    match.state = "dismissed"
    db.commit()
    db.refresh(match)
    return match
