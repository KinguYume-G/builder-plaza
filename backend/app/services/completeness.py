"""Profile completeness for the F1 Trust Gateway.

A simple additive score the UI shows as a progress ring during onboarding:
GitHub connected (40) + LinkedIn identity bound (40) + onboarding finished (20).
"""

from app.db.models import User

GITHUB_WEIGHT = 40
LINKEDIN_WEIGHT = 40
ONBOARDING_WEIGHT = 20


def compute(user: User) -> int:
    """Recompute completeness_pct from the user's current trust-gateway state.

    Persists onto ``user.completeness_pct`` and returns it. The caller commits.
    """
    pct = 0
    if user.github_profile is not None:
        pct += GITHUB_WEIGHT
    if user.linkedin_sub is not None:
        pct += LINKEDIN_WEIGHT
    if user.onboarding_complete:
        pct += ONBOARDING_WEIGHT

    user.completeness_pct = pct
    return pct
