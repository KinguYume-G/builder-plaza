"""F6 Trust Score Engine.

The score is a weighted blend of four components, each normalised to 0-100:

  github   -- contribution index from the cached F1 summary + F10 continuity
  linkedin -- professional tenure (simulated profiles carry tenure_years;
              the live OIDC path has none -> component unavailable)
  peer     -- average stars from peer reviews (unavailable until reviewed)
  payment  -- Stripe identity badge. MOCKED: always "verified", clearly
              flagged simulated=True so the UI can label it (academic
              integrity: no real Stripe verification happens).

Weights live in settings (trust_weight_*). Unavailable components are removed
and the remaining weights renormalised, so a user is scored only on evidence
that actually exists for them. Pure helpers take plain dicts/numbers so the
whole engine unit-tests without a DB.
"""

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.models import PeerReview, User
from app.services import activity_service

# Saturation caps: the value at which a signal earns full marks. Chosen for a
# student-project population (not to rank global OSS celebrities).
_CAPS = {
    "public_repos": 30,
    "followers": 100,
    "stars": 200,
    "recent_activity_count": 60,
}


def _ratio(value: float, cap: float) -> float:
    if cap <= 0:
        return 0.0
    return max(0.0, min(1.0, value / cap))


def github_component(summary: dict | None, active_weeks: int, total_weeks: int) -> dict:
    """Contribution index from the cached GitHub summary + continuity. Pure."""
    if not summary:
        return {"key": "github", "score": None, "detail": "GitHub not connected"}
    repos = _ratio(summary.get("public_repos") or 0, _CAPS["public_repos"])
    followers = _ratio(summary.get("followers") or 0, _CAPS["followers"])
    stars = _ratio(summary.get("stars") or 0, _CAPS["stars"])
    recent = _ratio(summary.get("recent_activity_count") or 0, _CAPS["recent_activity_count"])
    continuity = _ratio(active_weeks, total_weeks or 1)
    score = 100 * (
        0.20 * repos + 0.15 * followers + 0.25 * stars + 0.25 * recent + 0.15 * continuity
    )
    return {
        "key": "github",
        "score": round(score, 1),
        "detail": (
            f"{summary.get('public_repos') or 0} repos · "
            f"{summary.get('stars') or 0} stars · "
            f"{summary.get('recent_activity_count') or 0} recent events · "
            f"active {active_weeks}/{total_weeks} weeks"
        ),
    }


def linkedin_component(profile: dict | None) -> dict:
    """Professional tenure. Live OIDC has no employment data -> unavailable."""
    if not profile:
        return {"key": "linkedin", "score": None, "detail": "LinkedIn not connected"}
    tenure = profile.get("tenure_years")
    if tenure is None:
        return {
            "key": "linkedin",
            "score": None,
            "detail": "Tenure not available from LinkedIn OIDC",
        }
    score = 100 * _ratio(float(tenure), 10.0)
    return {
        "key": "linkedin",
        "score": round(score, 1),
        "detail": f"{tenure} year(s) professional tenure at {profile.get('company') or '—'}",
    }


def peer_component(avg_stars: float | None, review_count: int) -> dict:
    """Average peer-review stars mapped 1-5 -> 0-100. Pure."""
    if avg_stars is None or review_count == 0:
        return {"key": "peer", "score": None, "detail": "No peer reviews yet"}
    score = 100 * max(0.0, min(1.0, (avg_stars - 1.0) / 4.0))
    return {
        "key": "peer",
        "score": round(score, 1),
        "detail": f"{review_count} review(s) · {avg_stars:.1f}★ average",
    }


def payment_component() -> dict:
    """Stripe identity badge -- SIMULATED, always flagged as such."""
    return {
        "key": "payment",
        "score": 100.0,
        "simulated": True,
        "detail": "Stripe identity badge — verification simulated for demo",
    }


def blend(components: list[dict], weights: dict[str, float]) -> float:
    """Weighted average over AVAILABLE components, weights renormalised. Pure.

    A simulated component (the mocked Stripe badge) can top up a score built on
    real evidence but must never carry it alone: if every non-simulated
    component is unavailable the total is 0, so an empty profile can't earn
    trust from a mock.
    """
    if not any(
        component.get("score") is not None and not component.get("simulated")
        for component in components
    ):
        return 0.0
    total_weight = 0.0
    acc = 0.0
    for component in components:
        score = component.get("score")
        if score is None:
            continue
        weight = weights.get(component["key"], 0.0)
        total_weight += weight
        acc += weight * score
    if total_weight == 0:
        return 0.0
    return round(acc / total_weight, 1)


def _weights() -> dict[str, float]:
    return {
        "github": settings.trust_weight_github,
        "linkedin": settings.trust_weight_linkedin,
        "peer": settings.trust_weight_peer,
        "payment": settings.trust_weight_payment,
    }


_LABELS = {
    "github": "GitHub contribution",
    "linkedin": "LinkedIn tenure",
    "peer": "Peer reviews",
    "payment": "Payment identity",
}


def compute_trust(db: Session, user: User) -> dict:
    """Assemble the full breakdown, persist users.trust_score, return it."""
    events = activity_service.get_user_events(db, user)
    weekly = activity_service.weekly_activity(events)
    active_weeks = sum(1 for bucket in weekly if bucket["count"] > 0)

    avg_stars, review_count = db.execute(
        select(func.avg(PeerReview.stars), func.count(PeerReview.id)).where(
            PeerReview.reviewee == user.id
        )
    ).one()

    weights = _weights()
    components = [
        github_component(user.github_profile, active_weeks, len(weekly)),
        linkedin_component(user.linkedin_profile),
        peer_component(float(avg_stars) if avg_stars is not None else None, review_count),
        payment_component(),
    ]
    total = blend(components, weights)

    user.trust_score = total
    db.commit()

    return {
        "user_id": user.id,
        "github_login": user.github_login,
        "total": total,
        "components": [
            {
                "key": component["key"],
                "label": _LABELS[component["key"]],
                "score": component.get("score"),
                "weight": weights[component["key"]],
                "available": component.get("score") is not None,
                "simulated": bool(component.get("simulated")),
                "detail": component.get("detail"),
            }
            for component in components
        ],
    }
