"""F8 Request Market contracts.

Two posting types with different required fields, enforced here at the
application layer (the DB keeps the union of columns nullable):

  maintainer -- a maintainer opens their repo for help: needs a linked
                project (with verified repos) and an access_tier.
  team_role  -- a founder/builder recruits for a team: stage, tech_stack and
                commitment are ALL required (F8's three-mandatory rule).
"""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field, model_validator

ACCESS_TIERS = ["claim_an_issue", "limited", "full"]


class RolePostingIn(BaseModel):
    posting_type: str
    role_desc: str = Field(min_length=10, max_length=2000)
    skills: list[str] = Field(default_factory=list, max_length=10)
    project_id: uuid.UUID | None = None
    stage: str | None = None
    tech_stack: str | None = None
    commitment: str | None = None
    access_tier: str | None = None

    @model_validator(mode="after")
    def _validate_by_type(self) -> "RolePostingIn":
        if self.posting_type == "maintainer":
            if self.project_id is None:
                raise ValueError("maintainer postings must link a project with verified repos")
            if self.access_tier not in ACCESS_TIERS:
                raise ValueError(f"access_tier must be one of {ACCESS_TIERS}")
        elif self.posting_type == "team_role":
            missing = [
                name
                for name, value in (
                    ("stage", self.stage),
                    ("tech_stack", self.tech_stack),
                    ("commitment", self.commitment),
                )
                if value is None or not str(value).strip()
            ]
            if missing:
                raise ValueError(
                    "team_role postings require stage, tech_stack and commitment "
                    f"(missing: {', '.join(missing)})"
                )
        else:
            raise ValueError("posting_type must be 'maintainer' or 'team_role'")
        return self


class RolePostingUpdateIn(BaseModel):
    role_desc: str | None = Field(default=None, min_length=10, max_length=2000)
    skills: list[str] | None = Field(default=None, max_length=10)
    stage: str | None = None
    tech_stack: str | None = None
    commitment: str | None = None
    access_tier: str | None = None
    status: str | None = None


class PostingOwnerOut(BaseModel):
    id: uuid.UUID
    github_login: str
    avatar_url: str | None = None
    primary_role: str
    trust_score: float = 0


class PostingRepoOut(BaseModel):
    repo: str
    stars: int = 0
    language: str | None = None
    pushed_at: str | None = None
    error: str | None = None


class RolePostingOut(BaseModel):
    id: uuid.UUID
    posting_type: str
    role_desc: str
    skills: list[str]
    project_id: uuid.UUID | None = None
    project_title: str | None = None
    stage: str | None = None
    tech_stack: str | None = None
    commitment: str | None = None
    access_tier: str | None = None
    status: str
    owner: PostingOwnerOut
    repos: list[PostingRepoOut] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime
