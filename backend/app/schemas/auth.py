from typing import Literal

from pydantic import BaseModel

from app.schemas.user import UserOut

PrimaryRole = Literal["builder", "collaborator", "founder"]


class DevLoginIn(BaseModel):
    github_login: str = "demo-builder"
    primary_role: PrimaryRole = "builder"


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
