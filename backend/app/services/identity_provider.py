"""LinkedIn identity behind the ADR-0003 same-interface dual implementation.

One ``IdentityProvider`` protocol, two implementations selected by
``settings.linkedin_mode``. Only ``LinkedInSimulated`` exists today: it serves
3-5 preset professional profiles returning OIDC-shaped claims (``sub``, ``name``,
``picture``) plus our ``tenure_years`` extension that Trust Score consumes. The
Flutter client is unaware which implementation is active; the simulated path is
watermarked "Simulated for demo" in the UI, per ADR-0003.
"""

from typing import Protocol

from fastapi import HTTPException, status

from app.core.config import settings

# OIDC-shaped preset profiles + our tenure_years extension. `sub` is the stable
# identity token stored on users.linkedin_sub; `id` is the selection handle the
# client passes back to /auth/linkedin/bind.
_SIMULATED_PROFILES: list[dict] = [
    {
        "id": "li_ryan",
        "sub": "sim|ryan-tan",
        "name": "Ryan Tan",
        "headline": "Indie Builder · Flutter & FastAPI",
        "company": "Self-employed",
        "title": "Founder",
        "tenure_years": 4,
        "picture": None,
    },
    {
        "id": "li_aisha",
        "sub": "sim|aisha-rahman",
        "name": "Aisha Rahman",
        "headline": "Open-Source Maintainer · Postgres & Python",
        "company": "Timescale",
        "title": "Staff Engineer",
        "tenure_years": 7,
        "picture": None,
    },
    {
        "id": "li_mei",
        "sub": "sim|mei-chen",
        "name": "Mei Chen",
        "headline": "Product Designer · non-technical",
        "company": "Grab",
        "title": "Senior Product Designer",
        "tenure_years": 6,
        "picture": None,
    },
    {
        "id": "li_marcus",
        "sub": "sim|marcus-lee",
        "name": "Marcus Lee",
        "headline": "Startup CTO · hiring",
        "company": "Stealth",
        "title": "CTO / Co-founder",
        "tenure_years": 9,
        "picture": None,
    },
]


class IdentityProvider(Protocol):
    """LinkedIn identity source. Live and simulated share this shape."""

    def list_profiles(self) -> list[dict]:
        """Selectable profiles for the consent screen."""
        ...

    def get_profile(self, profile_id: str) -> dict | None:
        """Resolve a selection handle to its full profile, or None if unknown."""
        ...


class LinkedInSimulated:
    """In-app consent screen over the fixed preset profiles (ADR-0003)."""

    def list_profiles(self) -> list[dict]:
        # Copies so callers can't mutate the module-level presets.
        return [dict(profile) for profile in _SIMULATED_PROFILES]

    def get_profile(self, profile_id: str) -> dict | None:
        for profile in _SIMULATED_PROFILES:
            if profile["id"] == profile_id:
                return dict(profile)
        return None


def get_identity_provider() -> IdentityProvider:
    """Select the LinkedIn implementation by settings.linkedin_mode.

    This `IdentityProvider` abstraction only ever had a simulated
    implementation (ADR-0003's LinkedInSimulated). The real OIDC flow was
    built as its own separate path instead -- see `linkedin_oauth.py` and the
    dedicated `/auth/linkedin/login` + `/auth/linkedin/callback` routes in
    `routers/auth.py` -- because it needs a browser redirect + callback
    round trip that doesn't fit this list/get-profile shape. The Flutter
    client already routes correctly by mode (`linkedin_step_screen.dart`
    picks the live-redirect screen or the simulated-consent screen), so
    `/auth/linkedin/profiles` and `/auth/linkedin/bind` -- which only make
    sense for the simulated, in-app consent flow -- are simulated-mode-only
    by design, not an unfinished live implementation.
    """
    if settings.linkedin_mode == "live":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "This endpoint is simulated-mode only. LINKEDIN_MODE=live uses "
                "/auth/linkedin/login and /auth/linkedin/callback instead."
            ),
        )
    return LinkedInSimulated()
