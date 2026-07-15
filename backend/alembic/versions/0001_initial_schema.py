"""initial schema

Revision ID: 0001_initial
Revises:
Create Date: 2026-07-15

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from pgvector.sqlalchemy import Vector

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None

_ENUMS = [
    "primary_role_enum",
    "project_card_status_enum",
    "intent_type_enum",
    "growth_trigger_enum",
    "match_state_enum",
    "collab_request_state_enum",
    "posting_type_enum",
    "access_tier_enum",
    "role_posting_status_enum",
]


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("github_login", sa.String, nullable=False, unique=True),
        sa.Column("linkedin_sub", sa.String, nullable=True, unique=True),
        sa.Column("primary_role", sa.Enum("builder", "collaborator", "founder", name="primary_role_enum"), nullable=False),
        sa.Column("completeness_pct", sa.Integer, nullable=False, server_default="0"),
        sa.Column("trust_score", sa.Numeric(5, 2), nullable=False, server_default="0"),
        sa.Column("reverify_flag", sa.Boolean, nullable=False, server_default="false"),
        sa.Column("avatar_s3_key", sa.String, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "project_cards",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("owner_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String, nullable=False),
        sa.Column("stage", sa.String, nullable=False, comment="Taxonomy not fixed by PRD; enforce candidate values at the application layer."),
        sa.Column("needs", sa.Text, nullable=True),
        sa.Column("demo_url", sa.String, nullable=True),
        sa.Column("team_division", sa.Text, nullable=True),
        sa.Column("repo_full_names", postgresql.ARRAY(sa.String), nullable=False, server_default="{}"),
        sa.Column("screenshot_s3_keys", postgresql.ARRAY(sa.String), nullable=False, server_default="{}"),
        sa.Column("status", sa.Enum("active", "archived", name="project_card_status_enum"), nullable=False, server_default="active"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "intents",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("intent_type", sa.Enum("seeking_cofounder", "seeking_maintainer", "open_to_chat", "not_open", name="intent_type_enum"), nullable=False),
        sa.Column("note", sa.Text, nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "growth_posts",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("project_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("project_cards.id", ondelete="CASCADE"), nullable=False),
        sa.Column("summary", sa.Text, nullable=False),
        sa.Column("source_events", postgresql.JSONB, nullable=False, server_default="[]"),
        sa.Column("trigger", sa.Enum("manual", "scheduled", name="growth_trigger_enum"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "matches",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("for_user", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("candidate", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("score", sa.Numeric(5, 4), nullable=False),
        sa.Column("exploratory", sa.Boolean, nullable=False, server_default="false"),
        sa.Column("match_reason", sa.Text, nullable=False),
        sa.Column("state", sa.Enum("active", "dismissed", name="match_state_enum"), nullable=False, server_default="active"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("for_user", "candidate", name="uq_matches_for_user_candidate"),
    )

    op.create_table(
        "collab_requests",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("from_user", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("to_user", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("intent_type", sa.String, nullable=False, comment="Value set not enumerated in PRD F7; confirm whether it mirrors intents.intent_type."),
        sa.Column("context_ref", postgresql.UUID(as_uuid=True), nullable=True, comment="Polymorphic pointer at a project_cards.id or role_postings.id; no DB-level FK."),
        sa.Column("pitch", sa.Text, nullable=False),
        sa.Column("state", sa.Enum("pending", "accepted", "declined", "withdrawn", name="collab_request_state_enum"), nullable=False, server_default="pending"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "role_postings",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("owner_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("project_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("project_cards.id", ondelete="SET NULL"), nullable=True),
        sa.Column("posting_type", sa.Enum("maintainer", "team_role", name="posting_type_enum"), nullable=False),
        sa.Column("role_desc", sa.Text, nullable=False),
        sa.Column("skills", postgresql.ARRAY(sa.String), nullable=False, server_default="{}"),
        sa.Column("stage", sa.String, nullable=True, comment="Required only for team_role postings (F8); taxonomy TBD, enforce at application layer."),
        sa.Column("tech_stack", sa.String, nullable=True, comment="Required only for team_role postings (F8)."),
        sa.Column("commitment", sa.String, nullable=True, comment="Required only for team_role postings (F8)."),
        sa.Column("access_tier", sa.Enum("claim_an_issue", "limited", "full", name="access_tier_enum"), nullable=True, comment="Required only for maintainer postings (F8)."),
        sa.Column("status", sa.Enum("open", "closed", name="role_posting_status_enum"), nullable=False, server_default="open"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "peer_reviews",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("reviewer", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("reviewee", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("collab_request", postgresql.UUID(as_uuid=True), sa.ForeignKey("collab_requests.id", ondelete="CASCADE"), nullable=False),
        sa.Column("stars", sa.Integer, nullable=False),
        sa.Column("tags", postgresql.ARRAY(sa.String), nullable=False, server_default="{}"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("stars >= 1 AND stars <= 5", name="ck_peer_reviews_stars_range"),
        sa.UniqueConstraint("collab_request", "reviewer", name="uq_peer_reviews_request_reviewer"),
    )

    op.create_table(
        "skill_embeddings",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("embedding", Vector(384), nullable=False),
        sa.Column("source_digest", sa.Text, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    # No ANN index (ivfflat/hnsw) yet: at seed scale (~12 users, ADR-0001) an
    # exact `<=>` scan is fast enough and ivfflat quality is poor with this
    # few rows. Add one once real data volume justifies it.

    op.create_table(
        "conversations",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("collab_request_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("collab_requests.id", ondelete="CASCADE"), nullable=False, unique=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "messages",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("conversation_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False),
        sa.Column("sender_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("body", sa.Text, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_messages_conversation_id", "messages", ["conversation_id"])


def downgrade() -> None:
    op.drop_table("messages")
    op.drop_table("conversations")
    op.drop_table("skill_embeddings")
    op.drop_table("peer_reviews")
    op.drop_table("role_postings")
    op.drop_table("collab_requests")
    op.drop_table("matches")
    op.drop_table("growth_posts")
    op.drop_table("intents")
    op.drop_table("project_cards")
    op.drop_table("users")

    for enum_name in _ENUMS:
        sa.Enum(name=enum_name).drop(op.get_bind(), checkfirst=True)

    op.execute("DROP EXTENSION IF EXISTS vector")
