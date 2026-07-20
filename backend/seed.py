"""One-shot demo seed for Builder Plaza.

    python seed.py            # wipe app tables and reseed 12 accounts
    python seed.py --no-github  # skip live GitHub fetches (canned profiles only)

12 accounts: five builder personas (P1-P5), three collaborators, three
founders, and the demo main account. GitHub profiles come from REAL public
accounts (fetched live, cached into users.github_profile; canned fallback if
GitHub is unreachable); LinkedIn identities reuse the ADR-0003 simulated
presets so every persona reads coherently. Also seeds intents, projects with
real repos, a growth post, role postings, an accepted collaboration with a
conversation + peer reviews, and a pending request into the demo inbox --
enough to demo every feature from a cold start with ONE command.
"""

import argparse
import sys

from sqlalchemy import text

from app.db.models import (
    CollabRequest,
    Conversation,
    GrowthPost,
    Intent,
    Message,
    PeerReview,
    ProjectCard,
    RolePosting,
    User,
)
from app.db.session import SessionLocal
from app.services import bedrock_service, completeness
from app.services.github_provider import GitHubDev
from app.services.identity_provider import _SIMULATED_PROFILES

# (github_login, primary_role, linkedin preset index or None, intent_type)
# Real public GitHub accounts chosen for varied, recognisable footprints.
PERSONAS = [
    # P1-P5 · builders
    ("torvalds", "builder", 0, "seeking_maintainer"),
    ("antirez", "builder", 1, "seeking_cofounder"),
    ("tj", "builder", None, "open_to_chat"),
    ("mitchellh", "builder", 1, "seeking_maintainer"),
    ("yyx990803", "builder", 0, "seeking_cofounder"),
    # collaborators
    ("sindresorhus", "collaborator", 1, "open_to_chat"),
    ("gaearon", "collaborator", 2, "open_to_chat"),
    ("kentcdodds", "collaborator", 2, "not_open"),
    # founders
    ("gvanrossum", "founder", 3, "seeking_cofounder"),
    ("dhh", "founder", 3, "open_to_chat"),
    ("karpathy", "founder", 3, "seeking_cofounder"),
    # demo main account (the one you log in with for the demo)
    ("bp-demo", "builder", 0, "seeking_cofounder"),
]

# Wipe order respects FKs (children first).
WIPE_TABLES = [
    "messages",
    "conversations",
    "peer_reviews",
    "collab_requests",
    "matches",
    "skill_embeddings",
    "growth_posts",
    "role_postings",
    "project_cards",
    "intents",
    "users",
]

PROJECTS = [
    # (owner_login, title, stage, needs, repos)
    ("torvalds", "Kernel Companion", "scaling",
     "Looking for maintainers to triage the firehose.", ["torvalds/linux"]),
    ("antirez", "Tiny KV Cloud", "launched",
     "Managed hosting layer; needs a billing collaborator.", ["antirez/kilo"]),
    ("yyx990803", "Reactive Sheets", "building",
     "Spreadsheet engine on signals; needs a designer.", ["vuejs/core"]),
    ("gvanrossum", "TypedPipes", "prototype",
     "Typed data-pipeline DSL; seeking a founding engineer.", ["python/cpython"]),
    ("bp-demo", "Builder Plaza", "building",
     "This very app. Meta, yes.", ["flutter/flutter"]),
]


def canned_profile(login: str) -> dict:
    """Offline fallback GithubSummary shape."""
    return {
        "login": login,
        "name": login,
        "avatar_url": f"https://github.com/{login}.png",
        "public_repos": 12,
        "followers": 40,
        "top_languages": [{"language": "Python", "count": 5}],
        "topics": ["oss"],
        "recent_activity_count": 8,
        "stars": 120,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-github", action="store_true", help="skip live GitHub fetches")
    args = parser.parse_args()

    db = SessionLocal()
    github = GitHubDev()

    print("wiping app tables…")
    for table in WIPE_TABLES:
        db.execute(text(f"DELETE FROM {table}"))
    db.commit()

    print("creating users…")
    users: dict[str, User] = {}
    for login, role, linkedin_index, intent_type in PERSONAS:
        profile = None
        if not args.no_github:
            try:
                profile = github.fetch(login)
                print(f"  {login}: real GitHub profile ({profile['public_repos']} repos)")
            except Exception as exc:  # canned fallback keeps the seed one-shot
                print(f"  {login}: GitHub fetch failed ({exc}); using canned profile")
        if profile is None:
            profile = canned_profile(login)

        linkedin = None
        linkedin_sub = None
        if linkedin_index is not None:
            preset = dict(_SIMULATED_PROFILES[linkedin_index])
            # Unique sub per user (presets are shared archetypes).
            preset["sub"] = f"sim|seed-{login}"
            linkedin = preset
            linkedin_sub = preset["sub"]

        user = User(
            github_login=login,
            primary_role=role,
            github_profile=profile,
            linkedin_profile=linkedin,
            linkedin_sub=linkedin_sub,
            onboarding_complete=True,
        )
        completeness.compute(user)
        db.add(user)
        users[login] = user
        db.flush()
        db.add(Intent(user_id=user.id, intent_type=intent_type))
    db.commit()

    print("creating projects…")
    projects: dict[str, ProjectCard] = {}
    for owner_login, title, stage, needs, repos in PROJECTS:
        card = ProjectCard(
            owner_id=users[owner_login].id,
            title=title,
            stage=stage,
            needs=needs,
            repo_full_names=repos,
            screenshot_s3_keys=[],
            status="active",
        )
        db.add(card)
        projects[title] = card
    db.commit()

    print("seeding a growth post (template summary, no Bedrock call)…")
    events = [
        {"type": "PushEvent", "repo": "torvalds/linux", "actor": "torvalds",
         "created_at": "2026-07-18T10:00:00Z", "detail": "3 commit(s): sched fixes"},
        {"type": "ReleaseEvent", "repo": "torvalds/linux", "actor": "torvalds",
         "created_at": "2026-07-17T10:00:00Z", "detail": "release v6.99"},
    ]
    db.add(GrowthPost(
        project_id=projects["Kernel Companion"].id,
        summary=bedrock_service.fallback_summary("Kernel Companion", events),
        source_events=events,
        trigger="manual",
    ))
    db.commit()

    print("creating role postings…")
    db.add(RolePosting(
        owner_id=users["torvalds"].id,
        project_id=projects["Kernel Companion"].id,
        posting_type="maintainer",
        role_desc="Triage incoming patches, keep CI green, mentor first-time contributors.",
        skills=["C", "Git"],
        access_tier="claim_an_issue",
        status="open",
    ))
    db.add(RolePosting(
        owner_id=users["gvanrossum"].id,
        posting_type="team_role",
        role_desc="Founding engineer for TypedPipes: own the runtime and the CLI.",
        skills=["Python", "Rust"],
        stage="prototype",
        tech_stack="Python + Rust",
        commitment="20h/week",
        status="open",
    ))
    db.commit()

    print("creating an accepted collaboration + conversation + reviews…")
    accepted = CollabRequest(
        from_user=users["sindresorhus"].id,
        to_user=users["antirez"].id,
        intent_type="maintainer",
        pitch="I maintain 1000+ packages; happy to co-own the KV client libraries.",
        state="accepted",
    )
    db.add(accepted)
    db.flush()
    conversation = Conversation(collab_request_id=accepted.id)
    db.add(conversation)
    db.flush()
    db.add(Message(conversation_id=conversation.id,
                   sender_id=users["antirez"].id,
                   body="Welcome aboard — the client libs are yours."))
    db.add(Message(conversation_id=conversation.id,
                   sender_id=users["sindresorhus"].id,
                   body="Great. First PR incoming this week."))
    db.add(PeerReview(reviewer=users["antirez"].id,
                      reviewee=users["sindresorhus"].id,
                      collab_request=accepted.id,
                      stars=5, tags=["reliable", "fast"]))
    db.add(PeerReview(reviewer=users["sindresorhus"].id,
                      reviewee=users["antirez"].id,
                      collab_request=accepted.id,
                      stars=4, tags=["clear-scope"]))

    print("creating a pending request into the demo inbox…")
    db.add(CollabRequest(
        from_user=users["gaearon"].id,
        to_user=users["bp-demo"].id,
        intent_type="collaboration",
        pitch="Love the plaza concept — I can own the web front-end polish.",
        state="pending",
    ))
    db.commit()

    print(f"done: {len(users)} users, {len(projects)} projects. "
          "Log in as 'bp-demo' via dev-login for the demo main account.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"seed failed: {exc}", file=sys.stderr)
        raise
