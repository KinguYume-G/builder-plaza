"""Pure unit tests for the F6 Trust Score engine: component scoring, caps,
unavailable-component renormalisation, and the simulated payment flag."""

import pytest

from app.services import trust_service

WEIGHTS = {"github": 0.45, "linkedin": 0.20, "peer": 0.25, "payment": 0.10}


# --- github component -----------------------------------------------------

def test_github_component_full_marks_at_caps():
    summary = {"public_repos": 30, "followers": 100, "stars": 200, "recent_activity_count": 60}
    component = trust_service.github_component(summary, active_weeks=12, total_weeks=12)
    assert component["score"] == 100.0


def test_github_component_values_beyond_caps_clamp():
    summary = {"public_repos": 999, "followers": 9999, "stars": 99999, "recent_activity_count": 999}
    component = trust_service.github_component(summary, active_weeks=50, total_weeks=12)
    assert component["score"] == 100.0


def test_github_component_zero_profile():
    summary = {"public_repos": 0, "followers": 0, "stars": 0, "recent_activity_count": 0}
    component = trust_service.github_component(summary, active_weeks=0, total_weeks=12)
    assert component["score"] == 0.0


def test_github_component_missing_summary_unavailable():
    assert trust_service.github_component(None, 0, 12)["score"] is None


# --- linkedin component ---------------------------------------------------

def test_linkedin_tenure_scales_to_ten_years():
    assert trust_service.linkedin_component({"tenure_years": 5})["score"] == 50.0
    assert trust_service.linkedin_component({"tenure_years": 10})["score"] == 100.0
    assert trust_service.linkedin_component({"tenure_years": 15})["score"] == 100.0


def test_linkedin_live_oidc_without_tenure_is_unavailable():
    # The live OIDC path exposes no employment data (ADR-0003) -> null tenure.
    component = trust_service.linkedin_component({"sub": "live|x", "name": "X"})
    assert component["score"] is None
    assert "not available" in component["detail"]


def test_linkedin_not_connected_is_unavailable():
    assert trust_service.linkedin_component(None)["score"] is None


# --- peer component -------------------------------------------------------

@pytest.mark.parametrize(
    ("avg", "expected"), [(1.0, 0.0), (3.0, 50.0), (5.0, 100.0)]
)
def test_peer_star_mapping(avg, expected):
    assert trust_service.peer_component(avg, review_count=3)["score"] == expected


def test_peer_no_reviews_unavailable():
    assert trust_service.peer_component(None, 0)["score"] is None


# --- payment (mock) -------------------------------------------------------

def test_payment_component_is_flagged_simulated():
    component = trust_service.payment_component()
    assert component["simulated"] is True
    assert "simulated" in component["detail"].lower()


# --- blend ----------------------------------------------------------------

def test_blend_weighted_average_all_available():
    components = [
        {"key": "github", "score": 80.0},
        {"key": "linkedin", "score": 50.0},
        {"key": "peer", "score": 100.0},
        {"key": "payment", "score": 100.0},
    ]
    # 0.45*80 + 0.20*50 + 0.25*100 + 0.10*100 = 81.0
    assert trust_service.blend(components, WEIGHTS) == 81.0


def test_blend_renormalises_when_component_unavailable():
    components = [
        {"key": "github", "score": 80.0},
        {"key": "linkedin", "score": None},  # live OIDC: no tenure
        {"key": "peer", "score": None},  # no reviews yet
        {"key": "payment", "score": 100.0},
    ]
    # (0.45*80 + 0.10*100) / (0.45 + 0.10) = 83.6
    assert trust_service.blend(components, WEIGHTS) == 83.6


def test_blend_all_unavailable_is_zero():
    assert trust_service.blend([{"key": "github", "score": None}], WEIGHTS) == 0.0


def test_blend_simulated_badge_cannot_carry_the_score_alone():
    # An empty profile with only the mocked Stripe badge must score 0.
    components = [
        {"key": "github", "score": None},
        {"key": "linkedin", "score": None},
        {"key": "peer", "score": None},
        {"key": "payment", "score": 100.0, "simulated": True},
    ]
    assert trust_service.blend(components, WEIGHTS) == 0.0
