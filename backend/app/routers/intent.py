"""F3 Intent Badge: the current user's single intent row (PK = user_id)."""

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.models import Intent, User
from app.db.session import get_db
from app.schemas.intent import IntentIn, IntentOut

router = APIRouter(tags=["intent"])


@router.get("/me/intent", response_model=IntentOut | None)
def get_intent(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> IntentOut | None:
    intent = db.get(Intent, current_user.id)
    if intent is None:
        return None
    return IntentOut(intent_type=intent.intent_type, note=intent.note)


@router.put("/me/intent", response_model=IntentOut)
def set_intent(
    payload: IntentIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> IntentOut:
    """Upsert the intent row keyed on user_id."""
    intent = db.get(Intent, current_user.id)
    if intent is None:
        intent = Intent(user_id=current_user.id)
        db.add(intent)
    intent.intent_type = payload.intent_type
    intent.note = payload.note
    db.commit()
    db.refresh(intent)
    return IntentOut(intent_type=intent.intent_type, note=intent.note)


@router.delete("/me/intent", status_code=status.HTTP_204_NO_CONTENT)
def delete_intent(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Response:
    intent = db.get(Intent, current_user.id)
    if intent is not None:
        db.delete(intent)
        db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
