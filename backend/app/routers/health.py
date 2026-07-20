from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import get_db

router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "environment": settings.environment}


@router.get("/health/db")
def health_db(db: Session = Depends(get_db)) -> dict[str, str | int]:
    user_count = db.execute(text("SELECT COUNT(*) FROM users")).scalar_one()
    return {"status": "ok", "users_count": user_count}
