"""API integration: F7 Controlled DM -- send -> accept -> conversation ->
messages, plus the negative cases dev doc §17.3 calls out explicitly
(self-request, duplicate-pending, non-participant reading a conversation)."""

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from tests.conftest import auth_headers, make_user

PITCH = "I'd love to help build the Rust caching layer for this project."


def _send(client: TestClient, sender, to_user_id: str, **overrides) -> dict:
    payload = {"to_user": to_user_id, "intent_type": "collaboration", "pitch": PITCH}
    payload.update(overrides)
    res = client.post("/requests", json=payload, headers=auth_headers(sender))
    return res


def test_send_accept_opens_conversation_and_messages_flow(
    client: TestClient, db_session: Session
) -> None:
    sender = make_user(db_session)
    recipient = make_user(db_session)

    sent = _send(client, sender, str(recipient.id))
    assert sent.status_code == 201
    request_id = sent.json()["id"]
    assert sent.json()["state"] == "pending"

    inbox = client.get("/requests/inbox", headers=auth_headers(recipient))
    assert any(r["id"] == request_id for r in inbox.json())

    outbox = client.get("/requests/sent", headers=auth_headers(sender))
    assert any(r["id"] == request_id for r in outbox.json())

    accepted = client.post(
        f"/requests/{request_id}/accept", headers=auth_headers(recipient)
    )
    assert accepted.status_code == 200
    assert accepted.json()["state"] == "accepted"
    conversation_id = accepted.json()["conversation_id"]
    assert conversation_id is not None

    convos = client.get("/conversations", headers=auth_headers(sender))
    assert any(c["id"] == conversation_id for c in convos.json())

    sent_msg = client.post(
        f"/conversations/{conversation_id}/messages",
        json={"body": "Great, let's start with the API contract."},
        headers=auth_headers(sender),
    )
    assert sent_msg.status_code == 201

    messages = client.get(
        f"/conversations/{conversation_id}/messages", headers=auth_headers(recipient)
    )
    assert messages.status_code == 200
    assert any(m["body"].startswith("Great") for m in messages.json())


def test_cannot_send_request_to_self(client: TestClient, db_session: Session) -> None:
    user = make_user(db_session)
    res = _send(client, user, str(user.id))
    assert res.status_code == 400


def test_duplicate_pending_request_is_blocked(
    client: TestClient, db_session: Session
) -> None:
    sender = make_user(db_session)
    recipient = make_user(db_session)

    first = _send(client, sender, str(recipient.id))
    assert first.status_code == 201

    second = _send(client, sender, str(recipient.id))
    assert second.status_code == 409


def test_non_participant_cannot_read_conversation(
    client: TestClient, db_session: Session
) -> None:
    sender = make_user(db_session)
    recipient = make_user(db_session)
    stranger = make_user(db_session)

    sent = _send(client, sender, str(recipient.id))
    request_id = sent.json()["id"]
    accepted = client.post(
        f"/requests/{request_id}/accept", headers=auth_headers(recipient)
    )
    conversation_id = accepted.json()["conversation_id"]

    res = client.get(
        f"/conversations/{conversation_id}/messages", headers=auth_headers(stranger)
    )
    assert res.status_code == 403


def test_only_recipient_can_accept(client: TestClient, db_session: Session) -> None:
    sender = make_user(db_session)
    recipient = make_user(db_session)
    sent = _send(client, sender, str(recipient.id))
    request_id = sent.json()["id"]

    res = client.post(f"/requests/{request_id}/accept", headers=auth_headers(sender))
    assert res.status_code == 403
