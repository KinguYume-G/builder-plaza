"""trust gateway

Adds the F1 Dual-Source Trust Gateway columns to ``users``: cached GitHub
summary, bound LinkedIn profile, and the onboarding-complete flag.

Revision ID: 0002_trust_gateway
Revises: 0001_initial
Create Date: 2026-07-20

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0002_trust_gateway"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("github_profile", postgresql.JSONB, nullable=True))
    op.add_column("users", sa.Column("linkedin_profile", postgresql.JSONB, nullable=True))
    op.add_column(
        "users",
        sa.Column("onboarding_complete", sa.Boolean, nullable=False, server_default="false"),
    )


def downgrade() -> None:
    op.drop_column("users", "onboarding_complete")
    op.drop_column("users", "linkedin_profile")
    op.drop_column("users", "github_profile")
