"""F5 engine tests (scored deliverable): deterministic GPR ranking with a
fixed seed, always-non-empty Match Reasons, and the epsilon-greedy exploration
rate. Pure — no DB, no encoder download."""

import random

import pytest

from app.services.matching import scoring
from app.services.matching.credibility import credibility_summary

# --- GPR scoring: deterministic and sensibly ordered ----------------------

def test_gpr_scores_are_deterministic_across_calls():
    rows = [
        [0.9, 0.8, 1.0, 1.0],
        [0.5, 0.5, 0.0, 1.0],
        [0.2, 0.1, 0.0, 0.0],
    ]
    first = scoring.score_pairs(rows)
    second = scoring.score_pairs(rows)
    assert first == second


def test_gpr_ranks_similarity_dominant_pairs_higher():
    high = scoring.score_pairs([[0.95, 0.9, 1.0, 1.0]])[0]
    mid = scoring.score_pairs([[0.60, 0.5, 1.0, 1.0]])[0]
    low = scoring.score_pairs([[0.15, 0.2, 0.0, 0.0]])[0]
    assert high > mid > low


def test_gpr_scores_clamped_to_unit_interval():
    rows = [[1.0, 1.0, 1.0, 1.0], [0.0, 0.0, 0.0, 0.0]]
    for score in scoring.score_pairs(rows):
        assert 0.0 <= score <= 1.0


def test_topk_order_stable_with_fixed_inputs():
    rows = [
        [0.9, 0.2, 1.0, 1.0],
        [0.8, 0.9, 0.0, 1.0],
        [0.7, 0.7, 1.0, 0.0],
        [0.6, 0.1, 0.0, 1.0],
        [0.4, 0.8, 1.0, 1.0],
    ]
    order_a = sorted(range(len(rows)), key=lambda i: -scoring.score_pairs(rows)[i])
    order_b = sorted(range(len(rows)), key=lambda i: -scoring.score_pairs(rows)[i])
    assert order_a == order_b


# --- pair features --------------------------------------------------------

def test_pair_features_clamps_and_encodes():
    features = scoring.pair_features(1.7, 250.0, "builder", "founder", True)
    assert features == [1.0, 1.0, 1.0, 1.0]
    features = scoring.pair_features(-0.2, -5.0, "builder", "builder", False)
    assert features == [0.0, 0.0, 0.0, 0.0]


# --- epsilon-greedy exploration -------------------------------------------

def test_exploration_rate_close_to_epsilon():
    rng = random.Random(42)
    rounds = 2000
    explored = sum(
        1
        for _ in range(rounds)
        if scoring.pick_exploration_slot(10, 10, rng) is not None
    )
    assert explored / rounds == pytest.approx(scoring.EXPLORATION_EPSILON, abs=0.03)


def test_exploration_never_fires_without_pool():
    rng = random.Random(42)
    assert all(
        scoring.pick_exploration_slot(10, 0, rng) is None for _ in range(100)
    )


def test_exploration_index_within_pool():
    rng = random.Random(7)
    for _ in range(200):
        index = scoring.pick_exploration_slot(10, 5, rng)
        assert index is None or 0 <= index < 5


# --- match reason: ALWAYS non-empty ---------------------------------------

@pytest.mark.parametrize(
    ("shared", "role_a", "role_b", "exploratory"),
    [
        (["Python", "Flutter"], "builder", "founder", False),
        ([], "builder", "founder", False),
        ([], "builder", "builder", False),
        ([], "builder", "builder", True),
    ],
)
def test_match_reason_never_empty(shared, role_a, role_b, exploratory):
    reason = scoring.match_reason(shared, role_a, role_b, exploratory)
    assert reason.strip()


def test_match_reason_mentions_shared_skills_and_roles():
    reason = scoring.match_reason(["Python", "pgvector"], "builder", "founder", False)
    assert "Python" in reason
    assert "builder × founder" in reason


def test_match_reason_flags_exploration():
    reason = scoring.match_reason([], "builder", "builder", True)
    assert "Exploration" in reason


# --- credibility summary (plain language) ---------------------------------

def test_credibility_summary_plain_language_for_full_profile():
    summary, highlights = credibility_summary(
        github_login="aisha",
        primary_role="collaborator",
        github_summary={
            "public_repos": 20,
            "stars": 150,
            "top_languages": [{"language": "Python", "count": 9}],
        },
        active_weeks=9,
        total_weeks=12,
        linkedin_profile={"tenure_years": 7, "company": "Timescale"},
        avg_stars=4.5,
        review_count=2,
    )
    assert "@aisha" in summary
    assert "20 public project(s)" in summary
    assert "9 of the last 12 weeks" in summary
    assert any("7 year(s)" in highlight for highlight in highlights)
    assert any("4.5★" in highlight for highlight in highlights)


def test_credibility_summary_handles_empty_profile():
    summary, highlights = credibility_summary(
        github_login="ghost",
        primary_role="builder",
        github_summary=None,
        active_weeks=0,
        total_weeks=12,
        linkedin_profile=None,
        avg_stars=None,
        review_count=0,
    )
    assert "not connected a GitHub account" in summary
    assert any("No peer reviews yet" in highlight for highlight in highlights)
