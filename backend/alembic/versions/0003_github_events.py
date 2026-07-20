"""github events cache

F10 Verified Activity: persist the user's recent public GitHub events
(normalised) plus the fetch time, so the activity timeline and ownership
evidence render from stored data instead of hitting GitHub on every view.

Revision ID: 0003_github_events
Revises: 0002_trust_gateway
Create Date: 2026-07-20

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0003_github_events"
down_revision = "0002_trust_gateway"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("github_events", postgresql.JSONB, nullable=True))
    op.add_column(
        "users",
        sa.Column("github_events_fetched_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "github_events_fetched_at")
    op.drop_column("users", "github_events")
