"""F7 Controlled DM request/response contracts."""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.services.collab_service import REQUEST_INTENT_TYPES


class UserLiteOut(BaseModel):
    id: uuid.UUID
    github_login: str
    avatar_url: str | None = None
    primary_role: str


class CollabRequestIn(BaseModel):
    to_user: uuid.UUID
    intent_type: str
    pitch: str = Field(min_length=20, max_length=1000)
    context_ref: uuid.UUID | None = None

    @field_validator("intent_type")
    @classmethod
    def _valid_intent(cls, value: str) -> str:
        if value not in REQUEST_INTENT_TYPES:
            raise ValueError(
                f"intent_type must be one of {sorted(REQUEST_INTENT_TYPES)}"
            )
        return value


class CollabRequestOut(BaseModel):
    id: uuid.UUID
    from_user: UserLiteOut
    to_user: UserLiteOut
    intent_type: str
    pitch: str
    context_ref: uuid.UUID | None = None
    state: str
    conversation_id: uuid.UUID | None = None
    created_at: datetime
    updated_at: datetime


class MessageIn(BaseModel):
    body: str = Field(min_length=1, max_length=2000)


class MessageOut(BaseModel):
    id: uuid.UUID
    conversation_id: uuid.UUID
    sender_id: uuid.UUID
    sender_login: str
    body: str
    created_at: datetime


class ConversationOut(BaseModel):
    id: uuid.UUID
    collab_request_id: uuid.UUID
    counterpart: UserLiteOut
    intent_type: str
    last_message: MessageOut | None = None
    created_at: datetime
