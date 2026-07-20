"""F6 Trust Score response/request contracts."""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class TrustComponentOut(BaseModel):
    key: str
    label: str
    score: float | None = None
    weight: float
    available: bool
    simulated: bool = False
    detail: str | None = None


class TrustScoreOut(BaseModel):
    user_id: uuid.UUID
    github_login: str
    total: float
    components: list[TrustComponentOut]


class PeerReviewIn(BaseModel):
    collab_request_id: uuid.UUID
    stars: int = Field(ge=1, le=5)
    tags: list[str] = Field(default_factory=list, max_length=5)


class PeerReviewOut(BaseModel):
    id: uuid.UUID
    reviewer_id: uuid.UUID
    reviewer_login: str
    reviewee_id: uuid.UUID
    stars: int
    tags: list[str]
    created_at: datetime
