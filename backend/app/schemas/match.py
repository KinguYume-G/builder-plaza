"""F5 matching response contracts."""

import uuid
from datetime import datetime

from pydantic import BaseModel


class MatchCandidateOut(BaseModel):
    id: uuid.UUID
    github_login: str
    avatar_url: str | None = None
    primary_role: str
    trust_score: float
    headline: str | None = None


class MatchOut(BaseModel):
    id: uuid.UUID
    candidate: MatchCandidateOut
    score: float
    exploratory: bool
    match_reason: str
    state: str
    created_at: datetime


class CredibilitySummaryOut(BaseModel):
    user_id: uuid.UUID
    github_login: str
    summary: str
    highlights: list[str]
