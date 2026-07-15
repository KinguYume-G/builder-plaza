from fastapi import Depends, FastAPI
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import get_db

app = FastAPI(title="Builder Plaza API", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "environment": settings.environment}


@app.get("/health/db")
def health_db(db: Session = Depends(get_db)) -> dict[str, str | int]:
    user_count = db.execute(text("SELECT COUNT(*) FROM users")).scalar_one()
    return {"status": "ok", "users_count": user_count}
