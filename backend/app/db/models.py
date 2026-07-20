import uuid
from datetime import datetime

from pgvector.sqlalchemy import Vector
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base

# Mirrors PRD.md section 6.1 (ERD). A few enum-typed fields there have no
# concrete value set written down anywhere in the PRD -- those are modelled
# as plain strings with a comment instead of a Postgres ENUM, so we aren't
# baking in a taxonomy the product side hasn't actually decided.


def uuid_pk() -> Mapped[uuid.UUID]:
    return mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))


def created_at_col() -> Mapped[datetime]:
    return mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


def updated_at_col() -> Mapped[datetime]:
    return mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = uuid_pk()
    github_login: Mapped[str] = mapped_column(String, nullable=False, unique=True)
    linkedin_sub: Mapped[str | None] = mapped_column(String, unique=True)
    primary_role: Mapped[str] = mapped_column(
        Enum("builder", "collaborator", "founder", name="primary_role_enum"), nullable=False
    )
    completeness_pct: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    trust_score: Mapped[float] = mapped_column(Numeric(5, 2), nullable=False, server_default="0")
    reverify_flag: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    avatar_s3_key: Mapped[str | None] = mapped_column(String)
    # F1 Dual-Source Trust Gateway: cached GitHub summary (GithubSummary shape)
    # and the bound LinkedIn identity/profile (OIDC-shaped claims). onboarding
    # completes once both sources are connected and a role has been picked.
    github_profile: Mapped[dict | None] = mapped_column(JSONB)
    linkedin_profile: Mapped[dict | None] = mapped_column(JSONB)
    onboarding_complete: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()


class ProjectCard(Base):
    __tablename__ = "project_cards"

    id: Mapped[uuid.UUID] = uuid_pk()
    owner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    title: Mapped[str] = mapped_column(String, nullable=False)
    # F3 acceptance criteria name "stage" but never enumerate its values.
    stage: Mapped[str] = mapped_column(String, nullable=False)
    needs: Mapped[str | None] = mapped_column(Text)
    demo_url: Mapped[str | None] = mapped_column(String)
    team_division: Mapped[str | None] = mapped_column(Text)
    repo_full_names: Mapped[list[str]] = mapped_column(ARRAY(String), nullable=False, server_default="{}")
    screenshot_s3_keys: Mapped[list[str]] = mapped_column(ARRAY(String), nullable=False, server_default="{}")
    status: Mapped[str] = mapped_column(
        Enum("active", "archived", name="project_card_status_enum"), nullable=False, server_default="active"
    )
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()


class Intent(Base):
    __tablename__ = "intents"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    intent_type: Mapped[str] = mapped_column(
        Enum("seeking_cofounder", "seeking_maintainer", "open_to_chat", "not_open", name="intent_type_enum"),
        nullable=False,
    )
    note: Mapped[str | None] = mapped_column(Text)
    updated_at: Mapped[datetime] = updated_at_col()


class GrowthPost(Base):
    __tablename__ = "growth_posts"

    id: Mapped[uuid.UUID] = uuid_pk()
    project_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("project_cards.id", ondelete="CASCADE"), nullable=False
    )
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    source_events: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default="[]")
    trigger: Mapped[str] = mapped_column(
        Enum("manual", "scheduled", name="growth_trigger_enum"), nullable=False
    )
    created_at: Mapped[datetime] = created_at_col()


class Match(Base):
    __tablename__ = "matches"
    __table_args__ = (UniqueConstraint("for_user", "candidate", name="uq_matches_for_user_candidate"),)

    id: Mapped[uuid.UUID] = uuid_pk()
    for_user: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    candidate: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    score: Mapped[float] = mapped_column(Numeric(5, 4), nullable=False)
    exploratory: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default="false")
    match_reason: Mapped[str] = mapped_column(Text, nullable=False)
    state: Mapped[str] = mapped_column(
        Enum("active", "dismissed", name="match_state_enum"), nullable=False, server_default="active"
    )
    created_at: Mapped[datetime] = created_at_col()


class CollabRequest(Base):
    __tablename__ = "collab_requests"

    id: Mapped[uuid.UUID] = uuid_pk()
    from_user: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    to_user: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    # F7 never enumerates this value set; confirm whether it should reuse
    # intents.intent_type before locking it down as a DB enum.
    intent_type: Mapped[str] = mapped_column(String, nullable=False)
    context_ref: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True))
    pitch: Mapped[str] = mapped_column(Text, nullable=False)
    state: Mapped[str] = mapped_column(
        Enum("pending", "accepted", "declined", "withdrawn", name="collab_request_state_enum"),
        nullable=False,
        server_default="pending",
    )
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()


class RolePosting(Base):
    __tablename__ = "role_postings"

    id: Mapped[uuid.UUID] = uuid_pk()
    owner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    project_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("project_cards.id", ondelete="SET NULL")
    )
    posting_type: Mapped[str] = mapped_column(
        Enum("maintainer", "team_role", name="posting_type_enum"), nullable=False
    )
    role_desc: Mapped[str] = mapped_column(Text, nullable=False)
    skills: Mapped[list[str]] = mapped_column(ARRAY(String), nullable=False, server_default="{}")
    # stage/tech_stack/commitment are required only for team_role postings
    # (F8); access_tier only for maintainer postings. Enforced at the
    # application layer, not the DB, since only one side applies per row.
    stage: Mapped[str | None] = mapped_column(String)
    tech_stack: Mapped[str | None] = mapped_column(String)
    commitment: Mapped[str | None] = mapped_column(String)
    access_tier: Mapped[str | None] = mapped_column(
        Enum("claim_an_issue", "limited", "full", name="access_tier_enum")
    )
    status: Mapped[str] = mapped_column(
        Enum("open", "closed", name="role_posting_status_enum"), nullable=False, server_default="open"
    )
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()


class PeerReview(Base):
    __tablename__ = "peer_reviews"
    __table_args__ = (
        CheckConstraint("stars >= 1 AND stars <= 5", name="ck_peer_reviews_stars_range"),
        UniqueConstraint("collab_request", "reviewer", name="uq_peer_reviews_request_reviewer"),
    )

    id: Mapped[uuid.UUID] = uuid_pk()
    reviewer: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    reviewee: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    collab_request: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("collab_requests.id", ondelete="CASCADE"), nullable=False
    )
    stars: Mapped[int] = mapped_column(Integer, nullable=False)
    tags: Mapped[list[str]] = mapped_column(ARRAY(String), nullable=False, server_default="{}")
    created_at: Mapped[datetime] = created_at_col()


class SkillEmbedding(Base):
    __tablename__ = "skill_embeddings"

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    # 384 dims -- sentence-transformers all-MiniLM-L6-v2, per ADR-0001.
    embedding: Mapped[list[float]] = mapped_column(Vector(384), nullable=False)
    source_digest: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = created_at_col()


# Referenced by the ERD's relationship arrows (COLLAB_REQUESTS ||--o|
# CONVERSATIONS : opens, CONVERSATIONS ||--o{ MESSAGES : contains) but not
# given field lists there; fields below are inferred from the F7 acceptance
# criteria (accept opens a conversation, messages persist in PostgreSQL).
class Conversation(Base):
    __tablename__ = "conversations"

    id: Mapped[uuid.UUID] = uuid_pk()
    collab_request_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("collab_requests.id", ondelete="CASCADE"), nullable=False, unique=True
    )
    created_at: Mapped[datetime] = created_at_col()


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[uuid.UUID] = uuid_pk()
    conversation_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False
    )
    sender_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    body: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = created_at_col()
