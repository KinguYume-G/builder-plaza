"""F5 scoring: Gaussian Process Regression over hand-labelled pairs, plus the
epsilon-greedy exploration slot and the Match Reason template (ADR-0001).

Everything here is pure/deterministic given its inputs: the GPR is fitted on a
FIXED tiny labelled set with a fixed random_state, and exploration takes an
injectable ``random.Random`` so tests can seed it.
"""

import random
from functools import lru_cache

from sklearn.gaussian_process import GaussianProcessRegressor
from sklearn.gaussian_process.kernels import RBF, WhiteKernel

# Feature vector per candidate pair:
#   [cosine_similarity 0-1, trust_candidate 0-1, role_complement 0/1, intent_open 0/1]
#
# The labelled set encodes the product's ranking policy rather than mined data
# (there is none yet): similarity matters most, then trust; a complementary
# role and an open intent lift a pair; a closed intent sinks it.
_TRAINING_PAIRS: list[tuple[list[float], float]] = [
    ([0.95, 0.9, 1.0, 1.0], 0.97),
    ([0.90, 0.5, 1.0, 1.0], 0.85),
    ([0.85, 0.8, 0.0, 1.0], 0.75),
    ([0.80, 0.3, 1.0, 1.0], 0.70),
    ([0.70, 0.9, 1.0, 1.0], 0.72),
    ([0.70, 0.2, 0.0, 1.0], 0.45),
    ([0.60, 0.6, 1.0, 0.0], 0.40),
    ([0.50, 0.9, 0.0, 1.0], 0.42),
    ([0.40, 0.5, 1.0, 1.0], 0.35),
    ([0.30, 0.8, 0.0, 0.0], 0.15),
    ([0.20, 0.1, 0.0, 1.0], 0.10),
    ([0.10, 0.5, 1.0, 0.0], 0.08),
]

EXPLORATION_EPSILON = 0.2

# Roles that complement each other for collaboration purposes.
_COMPLEMENTS = {
    ("builder", "collaborator"),
    ("collaborator", "builder"),
    ("builder", "founder"),
    ("founder", "builder"),
    ("founder", "collaborator"),
    ("collaborator", "founder"),
}


@lru_cache(maxsize=1)
def _gpr() -> GaussianProcessRegressor:
    """Fit once per process on the fixed labelled set. Deterministic."""
    X = [features for features, _label in _TRAINING_PAIRS]
    y = [label for _features, label in _TRAINING_PAIRS]
    model = GaussianProcessRegressor(
        kernel=RBF(length_scale=0.5) + WhiteKernel(noise_level=1e-3),
        normalize_y=True,
        random_state=42,
    )
    model.fit(X, y)
    return model


def role_complement(role_a: str, role_b: str) -> float:
    return 1.0 if (role_a, role_b) in _COMPLEMENTS else 0.0


def pair_features(
    cosine_sim: float,
    candidate_trust: float,
    role_a: str,
    role_b: str,
    intent_open: bool,
) -> list[float]:
    return [
        max(0.0, min(1.0, cosine_sim)),
        max(0.0, min(1.0, candidate_trust / 100.0)),
        role_complement(role_a, role_b),
        1.0 if intent_open else 0.0,
    ]


def score_pairs(feature_rows: list[list[float]]) -> list[float]:
    """GPR predictions clamped to [0, 1]."""
    if not feature_rows:
        return []
    predictions = _gpr().predict(feature_rows)
    return [float(max(0.0, min(1.0, prediction))) for prediction in predictions]


def pick_exploration_slot(
    ranked_count: int, pool_beyond: int, rng: random.Random
) -> int | None:
    """Epsilon-greedy: with probability EXPLORATION_EPSILON, choose an index
    into the beyond-top-N pool to surface as an exploratory match. Returns the
    pool index or None (no exploration this round)."""
    if pool_beyond <= 0 or ranked_count == 0:
        return None
    if rng.random() >= EXPLORATION_EPSILON:
        return None
    return rng.randrange(pool_beyond)


def match_reason(
    shared_terms: list[str],
    role_a: str,
    role_b: str,
    exploratory: bool,
) -> str:
    """Template Match Reason -- ALWAYS non-empty (F5 acceptance criteria)."""
    parts: list[str] = []
    if shared_terms:
        shown = ", ".join(shared_terms[:4])
        parts.append(f"Shared skills: {shown}")
    if role_complement(role_a, role_b):
        parts.append(f"Complementary roles: {role_a} × {role_b}")
    if exploratory:
        parts.append("Exploration pick — outside your usual matches")
    if not parts:
        parts.append("Similar profile focus based on verified activity")
    return ". ".join(parts) + "."
