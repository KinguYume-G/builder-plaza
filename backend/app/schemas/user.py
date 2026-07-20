import uuid

from pydantic import BaseModel, ConfigDict, Field, computed_field

from app.db.models import User


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    github_login: str
    linkedin_sub: str | None
    primary_role: str
    completeness_pct: int
    # trust_score is a Numeric column; cast to float so it serialises as a JSON number.
    trust_score: float
    reverify_flag: bool
    onboarding_complete: bool

    # Raw JSONB blobs back the computed fields below but aren't part of the API
    # surface themselves; excluded so UserOut stays a clean client contract.
    github_profile: dict | None = Field(default=None, exclude=True)
    linkedin_profile: dict | None = Field(default=None, exclude=True)

    @computed_field  # type: ignore[prop-decorator]
    @property
    def avatar_url(self) -> str | None:
        # F1: reuse the real GitHub avatar until Phase 3 presigns avatar_s3_key.
        if self.github_profile:
            return self.github_profile.get("avatar_url")
        return None

    @computed_field  # type: ignore[prop-decorator]
    @property
    def github_connected(self) -> bool:
        return self.github_profile is not None

    @computed_field  # type: ignore[prop-decorator]
    @property
    def linkedin_connected(self) -> bool:
        return self.linkedin_sub is not None

    @computed_field  # type: ignore[prop-decorator]
    @property
    def linkedin_headline(self) -> str | None:
        if self.linkedin_profile:
            return self.linkedin_profile.get("headline")
        return None

    @classmethod
    def from_user(cls, user: User) -> "UserOut":
        return cls.model_validate(user)
