"""missing FK indexes + partial unique pending-request guard

Bug-fix pass (backend audit): several foreign-key columns used as the primary
filter predicate in hot-path queries had no index (Postgres does not
auto-index FKs), and `collab_requests` had no DB-level guard against two
concurrent requests from the same sender to the same recipient both landing
in "pending" state -- the application-layer check in `collab_service.can_send`
is select-then-insert with no locking, so a race could create two pending
rows for the same (from_user, to_user) pair.

Revision ID: 0004_indexes_and_constraints
Revises: 0003_github_events
Create Date: 2026-07-29

"""
from alembic import op
import sqlalchemy as sa

revision = "0004_indexes_and_constraints"
down_revision = "0003_github_events"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index(
        "ix_project_cards_owner_id", "project_cards", ["owner_id"]
    )
    op.create_index(
        "ix_role_postings_owner_id", "role_postings", ["owner_id"]
    )
    op.create_index(
        "ix_collab_requests_from_user", "collab_requests", ["from_user"]
    )
    op.create_index(
        "ix_collab_requests_to_user", "collab_requests", ["to_user"]
    )
    op.create_index(
        "ix_peer_reviews_reviewee", "peer_reviews", ["reviewee"]
    )
    op.create_index(
        "ix_skill_embeddings_user_id", "skill_embeddings", ["user_id"]
    )

    # Make the constraint safe to apply to an existing demo database. If an
    # older application race already created duplicate pending rows, retain
    # the newest as pending and withdraw the older duplicates before adding
    # the unique index.
    op.execute(
        """
        WITH ranked AS (
            SELECT id,
                   row_number() OVER (
                       PARTITION BY from_user, to_user
                       ORDER BY created_at DESC, id DESC
                   ) AS position
            FROM collab_requests
            WHERE state = 'pending'
        )
        UPDATE collab_requests
        SET state = 'withdrawn', updated_at = now()
        WHERE id IN (SELECT id FROM ranked WHERE position > 1)
        """
    )

    # Partial unique index: at most one PENDING request per (from_user,
    # to_user) pair. Declined/withdrawn/accepted history is untouched --
    # `can_send` already allows a fresh request once the old one leaves
    # "pending" -- this only closes the race where two pending rows could
    # both be created concurrently before either commit is visible to the
    # other's SELECT.
    op.create_index(
        "uq_collab_requests_pending_pair",
        "collab_requests",
        ["from_user", "to_user"],
        unique=True,
        postgresql_where=sa.text("state = 'pending'"),
    )


def downgrade() -> None:
    op.drop_index("uq_collab_requests_pending_pair", table_name="collab_requests")
    op.drop_index("ix_skill_embeddings_user_id", table_name="skill_embeddings")
    op.drop_index("ix_peer_reviews_reviewee", table_name="peer_reviews")
    op.drop_index("ix_collab_requests_to_user", table_name="collab_requests")
    op.drop_index("ix_collab_requests_from_user", table_name="collab_requests")
    op.drop_index("ix_role_postings_owner_id", table_name="role_postings")
    op.drop_index("ix_project_cards_owner_id", table_name="project_cards")
