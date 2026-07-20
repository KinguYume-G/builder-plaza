import uuid
from datetime import datetime, timedelta, timezone

import jwt
import pytest

from app.core.config import settings
from app.core.security import ALGORITHM, create_access_token, decode_token

# Pure unit tests: no DB, no network. JWT round-trip and failure modes only.


def test_create_and_decode_round_trip() -> None:
    user_id = str(uuid.uuid4())
    token = create_access_token(user_id)

    assert decode_token(token) == user_id


def test_tampered_token_raises() -> None:
    token = create_access_token(str(uuid.uuid4()))
    tampered = token[:-2] + ("aa" if not token.endswith("aa") else "bb")

    with pytest.raises(jwt.InvalidTokenError):
        decode_token(tampered)


def test_wrong_secret_raises() -> None:
    token = jwt.encode(
        {"sub": "someone", "exp": datetime.now(timezone.utc) + timedelta(days=1)},
        "a-different-secret",
        algorithm=ALGORITHM,
    )

    with pytest.raises(jwt.InvalidTokenError):
        decode_token(token)


def test_expired_token_raises() -> None:
    expired = jwt.encode(
        {"sub": "someone", "exp": datetime.now(timezone.utc) - timedelta(seconds=1)},
        settings.jwt_secret,
        algorithm=ALGORITHM,
    )

    with pytest.raises(jwt.ExpiredSignatureError):
        decode_token(expired)


def test_missing_sub_raises() -> None:
    token = jwt.encode(
        {"exp": datetime.now(timezone.utc) + timedelta(days=1)},
        settings.jwt_secret,
        algorithm=ALGORITHM,
    )

    with pytest.raises(jwt.InvalidTokenError):
        decode_token(token)
