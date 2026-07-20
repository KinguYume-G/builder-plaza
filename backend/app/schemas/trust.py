"""Request/response schemas for the F1 Dual-Source Trust Gateway."""

from typing import Literal

from pydantic import BaseModel

from app.schemas.auth import PrimaryRole
from app.schemas.user import UserOut


class LanguageCount(BaseModel):
    language: str
    count: int


class GithubSummary(BaseModel):
    login: str
    name: str | None
    avatar_url: str | None
    public_repos: int
    followers: int
    top_languages: list[LanguageCount]
    topics: list[str]
    recent_activity_count: int
    stars: int


class LinkedInProfileOut(BaseModel):
    id: str
    sub: str
    name: str
    headline: str
    company: str
    title: str
    tenure_years: int
    picture: str | None


class GithubConnectOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
    github: GithubSummary


class GithubConnectIn(BaseModel):
    github_login: str


class LinkedInBindIn(BaseModel):
    profile_id: str


class RoleIn(BaseModel):
    primary_role: Literal["builder", "collaborator", "founder"]


# Reuse the shared PrimaryRole literal so the role taxonomy is defined once.
__all__ = [
    "GithubSummary",
    "LanguageCount",
    "LinkedInProfileOut",
    "GithubConnectOut",
    "GithubConnectIn",
    "LinkedInBindIn",
    "RoleIn",
    "PrimaryRole",
]
