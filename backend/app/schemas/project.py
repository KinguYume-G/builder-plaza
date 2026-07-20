"""Request/response schemas for F3 Project Card."""

import re
import uuid
from datetime import datetime
from typing import Literal
from urllib.parse import urlparse

from pydantic import BaseModel, Field, field_validator

from app.schemas.intent import IntentOut

# F3 names "stage" but the PRD never enumerates its values; this is the product
# taxonomy we settled on. Validated at the application layer (the DB column is a
# plain String, no enum).
STAGES = ["idea", "prototype", "building", "launched", "scaling"]

# owner/repo, e.g. "octocat/Hello-World". GitHub allows word chars, dot, hyphen.
_REPO_RE = re.compile(r"^[\w.-]+/[\w.-]+$")

# The three image types we accept for screenshot uploads.
ImageContentType = Literal["image/jpeg", "image/png", "image/webp"]


def _validate_stage(value: str) -> str:
    if value not in STAGES:
        raise ValueError(f"stage must be one of {STAGES}")
    return value


def _validate_demo_url(value: str | None) -> str | None:
    if value is None:
        return None
    parsed = urlparse(value)
    if parsed.scheme not in ("http", "https") or not parsed.netloc:
        raise ValueError("demo_url must be a valid http(s) URL")
    return value


def _validate_repos(value: list[str]) -> list[str]:
    if len(value) > 10:
        raise ValueError("at most 10 repos allowed")
    for full_name in value:
        if not _REPO_RE.match(full_name):
            raise ValueError(f"'{full_name}' is not a valid owner/repo")
    return value


class ProjectCreateIn(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    stage: str
    needs: str | None = Field(default=None, max_length=2000)
    demo_url: str | None = None
    team_division: str | None = Field(default=None, max_length=2000)
    repo_full_names: list[str] = Field(default_factory=list)

    _v_stage = field_validator("stage")(_validate_stage)
    _v_demo = field_validator("demo_url")(_validate_demo_url)
    _v_repos = field_validator("repo_full_names")(_validate_repos)


class ProjectUpdateIn(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=120)
    stage: str | None = None
    needs: str | None = Field(default=None, max_length=2000)
    demo_url: str | None = None
    team_division: str | None = Field(default=None, max_length=2000)
    repo_full_names: list[str] | None = None
    status: Literal["active", "archived"] | None = None

    @field_validator("stage")
    @classmethod
    def _v_stage(cls, value: str | None) -> str | None:
        return None if value is None else _validate_stage(value)

    @field_validator("demo_url")
    @classmethod
    def _v_demo(cls, value: str | None) -> str | None:
        return _validate_demo_url(value)

    @field_validator("repo_full_names")
    @classmethod
    def _v_repos(cls, value: list[str] | None) -> list[str] | None:
        return None if value is None else _validate_repos(value)


class ScreenshotUrlIn(BaseModel):
    content_type: ImageContentType


class ScreenshotKeyIn(BaseModel):
    key: str


class ScreenshotOut(BaseModel):
    key: str
    url: str


class ProjectOwnerOut(BaseModel):
    id: uuid.UUID
    github_login: str
    avatar_url: str | None
    primary_role: str


class ProjectCardOut(BaseModel):
    id: uuid.UUID
    owner_id: uuid.UUID
    title: str
    stage: str
    needs: str | None
    demo_url: str | None
    team_division: str | None
    repo_full_names: list[str]
    screenshots: list[ScreenshotOut]
    status: str
    created_at: datetime
    updated_at: datetime
    owner: ProjectOwnerOut
    intent: IntentOut | None


class RepoActivityOut(BaseModel):
    # Success shape carries the light repo stats; on failure only repo + error
    # are populated (all stat fields left None) so one bad repo never fails the
    # whole request.
    repo: str
    html_url: str | None = None
    stars: int | None = None
    language: str | None = None
    pushed_at: str | None = None
    open_issues: int | None = None
    description: str | None = None
    error: str | None = None
