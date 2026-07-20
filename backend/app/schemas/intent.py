"""Request/response schemas for F3 Intent Badge."""

from typing import Literal

from pydantic import BaseModel, Field

# Mirrors intents.intent_type_enum in the DB (app/db/models.py).
IntentType = Literal["seeking_cofounder", "seeking_maintainer", "open_to_chat", "not_open"]


class IntentIn(BaseModel):
    intent_type: IntentType
    note: str | None = Field(default=None, max_length=500)


class IntentOut(BaseModel):
    intent_type: str
    note: str | None
