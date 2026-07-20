"""F4 Growth Plaza response contracts."""

import uuid
from datetime import datetime

from pydantic import BaseModel

from app.schemas.project import ProjectOwnerOut


class GrowthPostOut(BaseModel):
    id: uuid.UUID
    project_id: uuid.UUID
    summary: str
    source_events: list[dict]
    trigger: str
    created_at: datetime


class PlazaItemOut(BaseModel):
    """A growth post enriched with just enough project/owner context to render
    a plaza card without extra round-trips."""

    post: GrowthPostOut
    project_title: str
    project_stage: str
    owner: ProjectOwnerOut


class RefreshGrowthOut(BaseModel):
    """POST /projects/{id}/refresh-growth result. ``post`` is null when no new
    activity was found since the last post (nothing written)."""

    refreshed: bool
    post: GrowthPostOut | None = None
