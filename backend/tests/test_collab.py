"""Pure unit tests for F7 Controlled DM rules: request validation and the
send-gating (duplicate pending, accepted, decline cooldown)."""

from datetime import datetime, timedelta, timezone

import pytest
from pydantic import ValidationError

from app.schemas.collab import CollabRequestIn, MessageIn
from app.services import collab_service

NOW = datetime(2026, 7, 20, 12, 0, tzinfo=timezone.utc)
UID = "0b6f39f4-9a2f-4a3e-8f2a-3a4b5c6d7e8f"


# --- schema validation ----------------------------------------------------

def test_request_requires_known_intent_type():
    with pytest.raises(ValidationError):
        CollabRequestIn(to_user=UID, intent_type="marriage", pitch="x" * 30)


@pytest.mark.parametrize("intent", ["cofounder", "maintainer", "collaboration", "chat"])
def test_request_accepts_valid_intents(intent):
    assert CollabRequestIn(to_user=UID, intent_type=intent, pitch="x" * 30).intent_type == intent


def test_pitch_must_be_substantive():
    # A structured pitch is the point of F7 -- 20 chars minimum.
    with pytest.raises(ValidationError):
        CollabRequestIn(to_user=UID, intent_type="chat", pitch="hi")


def test_message_body_bounds():
    with pytest.raises(ValidationError):
        MessageIn(body="")
    with pytest.raises(ValidationError):
        MessageIn(body="x" * 2001)
    assert MessageIn(body="hello").body == "hello"


# --- send gating ----------------------------------------------------------

def test_can_send_with_no_history():
    allowed, reason = collab_service.can_send([], now=NOW)
    assert allowed and reason is None


def test_cannot_send_with_pending():
    allowed, reason = collab_service.can_send(
        [{"state": "pending", "updated_at": NOW}], now=NOW
    )
    assert not allowed
    assert "pending" in reason


def test_cannot_send_when_already_accepted():
    allowed, reason = collab_service.can_send(
        [{"state": "accepted", "updated_at": NOW - timedelta(days=30)}], now=NOW
    )
    assert not allowed
    assert "conversation" in reason


def test_decline_cooldown_blocks_within_window():
    allowed, reason = collab_service.can_send(
        [{"state": "declined", "updated_at": NOW - timedelta(days=2)}], now=NOW
    )
    assert not allowed
    assert "declined recently" in reason


def test_decline_cooldown_expires():
    allowed, _reason = collab_service.can_send(
        [{"state": "declined", "updated_at": NOW - timedelta(days=8)}], now=NOW
    )
    assert allowed


def test_withdrawn_requests_do_not_block():
    allowed, _reason = collab_service.can_send(
        [{"state": "withdrawn", "updated_at": NOW}], now=NOW
    )
    assert allowed
