"""F7 Controlled DM: structured collaboration requests + gated conversations.

No raw contact details (emails, phones, socials) exist anywhere in these
contracts -- contact happens inside the platform conversation that an ACCEPTED
request opens, per the PRD's controlled-DM stance.
"""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.models import CollabRequest, Conversation, Message, User
from app.db.session import get_db
from app.schemas.collab import (
    CollabRequestIn,
    CollabRequestOut,
    ConversationOut,
    MessageIn,
    MessageOut,
    UserLiteOut,
)
from app.services import collab_service

router = APIRouter(tags=["requests"])


def _user_lite(user: User) -> UserLiteOut:
    profile = user.github_profile or {}
    return UserLiteOut(
        id=user.id,
        github_login=user.github_login,
        avatar_url=profile.get("avatar_url"),
        primary_role=user.primary_role,
    )


def _conversation_for(db: Session, request_id: uuid.UUID) -> Conversation | None:
    return db.execute(
        select(Conversation).where(Conversation.collab_request_id == request_id)
    ).scalar_one_or_none()


def _request_out(db: Session, request: CollabRequest) -> CollabRequestOut:
    conversation = _conversation_for(db, request.id)
    return CollabRequestOut(
        id=request.id,
        from_user=_user_lite(db.get(User, request.from_user)),
        to_user=_user_lite(db.get(User, request.to_user)),
        intent_type=request.intent_type,
        pitch=request.pitch,
        context_ref=request.context_ref,
        state=request.state,
        conversation_id=conversation.id if conversation else None,
        created_at=request.created_at,
        updated_at=request.updated_at,
    )


# --- requests -------------------------------------------------------------


@router.post("/requests", response_model=CollabRequestOut, status_code=status.HTTP_201_CREATED)
def send_request(
    payload: CollabRequestIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CollabRequestOut:
    if payload.to_user == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot send a request to yourself",
        )
    recipient = db.get(User, payload.to_user)
    if recipient is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    history = db.execute(
        select(CollabRequest).where(
            CollabRequest.from_user == current_user.id,
            CollabRequest.to_user == recipient.id,
        )
    ).scalars().all()
    allowed, reason = collab_service.can_send(
        [{"state": request.state, "updated_at": request.updated_at} for request in history]
    )
    if not allowed:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=reason)

    request = CollabRequest(
        from_user=current_user.id,
        to_user=recipient.id,
        intent_type=payload.intent_type,
        context_ref=payload.context_ref,
        pitch=payload.pitch,
        state="pending",
    )
    db.add(request)
    db.commit()
    db.refresh(request)
    return _request_out(db, request)


@router.get("/requests/inbox", response_model=list[CollabRequestOut])
def inbox(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[CollabRequestOut]:
    requests = (
        db.execute(
            select(CollabRequest)
            .where(CollabRequest.to_user == current_user.id)
            .order_by(CollabRequest.created_at.desc())
        )
        .scalars()
        .all()
    )
    return [_request_out(db, request) for request in requests]


@router.get("/requests/sent", response_model=list[CollabRequestOut])
def sent(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[CollabRequestOut]:
    requests = (
        db.execute(
            select(CollabRequest)
            .where(CollabRequest.from_user == current_user.id)
            .order_by(CollabRequest.created_at.desc())
        )
        .scalars()
        .all()
    )
    return [_request_out(db, request) for request in requests]


def _get_request(db: Session, request_id: uuid.UUID) -> CollabRequest:
    request = db.get(CollabRequest, request_id)
    if request is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Request not found")
    return request


def _transition(
    db: Session,
    request: CollabRequest,
    actor: User,
    must_be: str,
    new_state: str,
    actor_field: str,
) -> CollabRequest:
    allowed_actor = getattr(request, actor_field)
    if actor.id != allowed_actor:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed")
    if request.state != must_be:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Request is {request.state}, expected {must_be}",
        )
    request.state = new_state
    db.commit()
    db.refresh(request)
    return request


@router.post("/requests/{request_id}/accept", response_model=CollabRequestOut)
def accept(
    request_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CollabRequestOut:
    """Accepting opens the conversation -- the ONLY way a DM channel exists."""
    request = _transition(
        db, _get_request(db, request_id), current_user, "pending", "accepted", "to_user"
    )
    if _conversation_for(db, request.id) is None:
        db.add(Conversation(collab_request_id=request.id))
        db.commit()
    return _request_out(db, request)


@router.post("/requests/{request_id}/decline", response_model=CollabRequestOut)
def decline(
    request_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CollabRequestOut:
    request = _transition(
        db, _get_request(db, request_id), current_user, "pending", "declined", "to_user"
    )
    return _request_out(db, request)


@router.post("/requests/{request_id}/withdraw", response_model=CollabRequestOut)
def withdraw(
    request_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CollabRequestOut:
    request = _transition(
        db, _get_request(db, request_id), current_user, "pending", "withdrawn", "from_user"
    )
    return _request_out(db, request)


# --- conversations --------------------------------------------------------


def _get_conversation_for_participant(
    db: Session, conversation_id: uuid.UUID, user: User
) -> tuple[Conversation, CollabRequest]:
    conversation = db.get(Conversation, conversation_id)
    if conversation is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found"
        )
    request = db.get(CollabRequest, conversation.collab_request_id)
    if user.id not in (request.from_user, request.to_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a participant")
    return conversation, request


def _message_out(db: Session, message: Message) -> MessageOut:
    sender = db.get(User, message.sender_id)
    return MessageOut(
        id=message.id,
        conversation_id=message.conversation_id,
        sender_id=message.sender_id,
        sender_login=sender.github_login if sender else "",
        body=message.body,
        created_at=message.created_at,
    )


@router.get("/conversations", response_model=list[ConversationOut])
def list_conversations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[ConversationOut]:
    rows = db.execute(
        select(Conversation, CollabRequest)
        .join(CollabRequest, Conversation.collab_request_id == CollabRequest.id)
        .where(
            (CollabRequest.from_user == current_user.id)
            | (CollabRequest.to_user == current_user.id)
        )
        .order_by(Conversation.created_at.desc())
    ).all()

    out = []
    for conversation, request in rows:
        counterpart_id = (
            request.to_user if request.from_user == current_user.id else request.from_user
        )
        last = db.execute(
            select(Message)
            .where(Message.conversation_id == conversation.id)
            .order_by(Message.created_at.desc())
            .limit(1)
        ).scalar_one_or_none()
        out.append(
            ConversationOut(
                id=conversation.id,
                collab_request_id=request.id,
                counterpart=_user_lite(db.get(User, counterpart_id)),
                intent_type=request.intent_type,
                last_message=_message_out(db, last) if last else None,
                created_at=conversation.created_at,
            )
        )
    return out


@router.get("/conversations/{conversation_id}/messages", response_model=list[MessageOut])
def list_messages(
    conversation_id: uuid.UUID,
    after: uuid.UUID | None = Query(default=None, description="only messages after this id"),
    limit: int = Query(default=100, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[MessageOut]:
    """Poll target (the client refreshes every ~10s). ``after`` makes the poll
    incremental: pass the last-seen message id."""
    conversation, _request = _get_conversation_for_participant(
        db, conversation_id, current_user
    )
    stmt = select(Message).where(Message.conversation_id == conversation.id)
    if after is not None:
        anchor = db.get(Message, after)
        if anchor is not None:
            stmt = stmt.where(Message.created_at > anchor.created_at)
    stmt = stmt.order_by(Message.created_at.asc()).limit(limit)
    messages = db.execute(stmt).scalars().all()
    return [_message_out(db, message) for message in messages]


@router.post(
    "/conversations/{conversation_id}/messages",
    response_model=MessageOut,
    status_code=status.HTTP_201_CREATED,
)
def send_message(
    conversation_id: uuid.UUID,
    payload: MessageIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MessageOut:
    conversation, _request = _get_conversation_for_participant(
        db, conversation_id, current_user
    )
    message = Message(
        conversation_id=conversation.id,
        sender_id=current_user.id,
        body=payload.body,
    )
    db.add(message)
    db.commit()
    db.refresh(message)
    return _message_out(db, message)
