"""F5 embeddings: MiniLM-L6-v2 (384-dim, ADR-0001) -> skill_embeddings rows.

The model import/load is lazy and memoised: sentence-transformers drags in
torch, which we don't want at app import time (or in unit tests that only
exercise the pure engine parts).
"""

import hashlib

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import Intent, SkillEmbedding, User
from app.services.matching.skill_text import skill_text

_MODEL_NAME = "all-MiniLM-L6-v2"
_model = None


def _get_model():
    global _model
    if _model is None:
        from sentence_transformers import SentenceTransformer

        _model = SentenceTransformer(_MODEL_NAME)
    return _model


def digest(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def embed_text(text: str) -> list[float]:
    vector = _get_model().encode([text], normalize_embeddings=True)[0]
    return [float(value) for value in vector]


def upsert_user_embedding(db: Session, user: User) -> SkillEmbedding:
    """Embed the user's skill text, skipping the encoder when unchanged."""
    intent = db.get(Intent, user.id)
    text = skill_text(user, intent)
    text_digest = digest(text)

    existing = db.execute(
        select(SkillEmbedding).where(SkillEmbedding.user_id == user.id)
    ).scalar_one_or_none()
    if existing is not None and existing.source_digest == text_digest:
        return existing

    vector = embed_text(text)
    if existing is None:
        existing = SkillEmbedding(user_id=user.id, embedding=vector, source_digest=text_digest)
        db.add(existing)
    else:
        existing.embedding = vector
        existing.source_digest = text_digest
    db.commit()
    db.refresh(existing)
    return existing
