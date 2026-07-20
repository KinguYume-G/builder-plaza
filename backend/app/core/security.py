import uuid
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.models import User
from app.db.session import get_db

# HS256 custom JWT rooted in the GitHub-OAuth identity (JWT_SECRET signs it).
ALGORITHM = "HS256"
ACCESS_TOKEN_TTL = timedelta(days=7)

bearer_scheme = HTTPBearer(auto_error=True)


def create_access_token(user_id: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {"sub": str(user_id), "exp": now + ACCESS_TOKEN_TTL}
    return jwt.encode(payload, settings.jwt_secret, algorithm=ALGORITHM)


def decode_token(token: str) -> str:
    """Return the user id (sub). Raises jwt.InvalidTokenError on invalid/expired."""
    payload = jwt.decode(token, settings.jwt_secret, algorithms=[ALGORITHM])
    sub = payload.get("sub")
    if not sub:
        raise jwt.InvalidTokenError("missing sub claim")
    return sub


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        user_id = decode_token(credentials.credentials)
        user_uuid = uuid.UUID(user_id)
    except (jwt.InvalidTokenError, ValueError):
        raise credentials_exception

    user = db.get(User, user_uuid)
    if user is None:
        raise credentials_exception
    return user
