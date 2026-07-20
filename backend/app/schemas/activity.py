"""F10 Verified Activity + Ownership Evidence response contracts."""

import uuid
from datetime import datetime

from pydantic import BaseModel


class ActivityEventOut(BaseModel):
    type: str
    repo: str | None = None
    detail: str | None = None
    created_at: str | None = None


class ActivityTimelineOut(BaseModel):
    user_id: uuid.UUID
    github_login: str
    events: list[ActivityEventOut]
    fetched_at: datetime | None = None


class WeeklyActivityOut(BaseModel):
    week_start: str
    count: int


class RepoRoleOut(BaseModel):
    repo: str | None = None
    role: str
    stars: int = 0
    language: str | None = None
    pushed_at: str | None = None


class OwnershipEvidenceOut(BaseModel):
    user_id: uuid.UUID
    github_login: str
    weekly_activity: list[WeeklyActivityOut]
    active_weeks: int
    total_weeks: int
    repo_roles: list[RepoRoleOut]
