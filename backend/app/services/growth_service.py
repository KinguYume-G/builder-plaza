"""F4 Growth Plaza: incremental GitHub polling -> summarised growth posts.

For each repo on a project card we poll the public /repos/{full}/events feed
(reusing the F1 User-Agent/timeout conventions), keep only events NEWER than
the project's last growth post (incremental), normalise them to a compact
shape, and hand the batch to bedrock_service for summarisation. One repo
failing (rate limit, 404) never sinks the refresh -- it is just skipped.
"""

import uuid
from datetime import datetime, timedelta, timezone

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import GrowthPost, ProjectCard
from app.services import bedrock_service
from app.services.github_provider import (
    GITHUB_API_BASE,
    _TIMEOUT,
    _parse_github_time,
    github_headers,
)

# Event types that count as "growth" for the feed. Watch/Fork noise excluded.
_GROWTH_EVENT_TYPES = {
    "PushEvent",
    "PullRequestEvent",
    "CreateEvent",
    "ReleaseEvent",
    "IssuesEvent",
}

# First refresh (no prior post) looks back this far so the feed has content.
_INITIAL_WINDOW = timedelta(days=30)

# Cap the batch handed to the LLM so the prompt stays small.
_MAX_EVENTS = 40


def normalize_event(raw: dict, repo_full_name: str) -> dict:
    """Reduce a raw GitHub event to the compact shape stored in source_events."""
    payload = raw.get("payload") or {}
    detail = None
    event_type = raw.get("type")
    if event_type == "PushEvent":
        commits = payload.get("commits") or []
        # The events API sometimes omits the commits list; "size" still counts.
        count = len(commits) or payload.get("size") or 0
        detail = f"{count} commit(s)"
        if commits:
            detail += f": {commits[-1].get('message', '')[:80]}"
    elif event_type == "PullRequestEvent":
        pr = payload.get("pull_request") or {}
        detail = f"{payload.get('action', '')} PR: {pr.get('title', '')[:80]}"
    elif event_type == "CreateEvent":
        detail = f"created {payload.get('ref_type', '')} {payload.get('ref') or ''}".strip()
    elif event_type == "ReleaseEvent":
        release = payload.get("release") or {}
        detail = f"release {release.get('tag_name', '')}"
    elif event_type == "IssuesEvent":
        issue = payload.get("issue") or {}
        detail = f"{payload.get('action', '')} issue: {issue.get('title', '')[:80]}"

    return {
        "type": event_type,
        "repo": repo_full_name,
        "actor": (raw.get("actor") or {}).get("login"),
        "created_at": raw.get("created_at"),
        "detail": detail,
    }


def filter_new_events(
    raw_events: list[dict], repo_full_name: str, since: datetime
) -> list[dict]:
    """Pure: keep growth-type events strictly newer than ``since``, normalised."""
    kept = []
    for raw in raw_events:
        if raw.get("type") not in _GROWTH_EVENT_TYPES:
            continue
        created_at = _parse_github_time(raw.get("created_at"))
        if created_at is None or created_at <= since:
            continue
        kept.append(normalize_event(raw, repo_full_name))
    return kept


def _fetch_repo_events(client: httpx.Client, repo_full_name: str) -> list[dict]:
    response = client.get(
        f"{GITHUB_API_BASE}/repos/{repo_full_name}/events", params={"per_page": 100}
    )
    if response.status_code != 200:
        return []
    return response.json()


def collect_new_events(card: ProjectCard, since: datetime) -> list[dict]:
    """Fetch and merge new events for every repo on the card, newest first."""
    events: list[dict] = []
    try:
        with httpx.Client(timeout=_TIMEOUT, headers=github_headers()) as client:
            for repo_full_name in card.repo_full_names:
                try:
                    raw = _fetch_repo_events(client, repo_full_name)
                except httpx.HTTPError:
                    continue  # one bad repo never sinks the refresh
                events.extend(filter_new_events(raw, repo_full_name, since))
    except httpx.HTTPError:
        pass
    events.sort(key=lambda event: event.get("created_at") or "", reverse=True)
    return events[:_MAX_EVENTS]


def last_post_time(db: Session, project_id: uuid.UUID) -> datetime | None:
    return db.execute(
        select(GrowthPost.created_at)
        .where(GrowthPost.project_id == project_id)
        .order_by(GrowthPost.created_at.desc())
        .limit(1)
    ).scalar_one_or_none()


def refresh_growth(db: Session, card: ProjectCard, trigger: str) -> GrowthPost | None:
    """Poll GitHub for events newer than the last post; write one GrowthPost.

    Returns None when there is nothing new (no post written), so callers can
    tell the user "no new activity" instead of spamming empty posts.
    """
    since = last_post_time(db, card.id) or (
        datetime.now(timezone.utc) - _INITIAL_WINDOW
    )
    events = collect_new_events(card, since)
    if not events:
        return None

    summary, _used_llm = bedrock_service.summarize_events(card.title, events)
    post = GrowthPost(
        project_id=card.id,
        summary=summary,
        source_events=events,
        trigger=trigger,
    )
    db.add(post)
    db.commit()
    db.refresh(post)
    return post


def refresh_all_active(db: Session) -> int:
    """Scheduled path (EventBridge daily): refresh every active card with repos.

    Returns the number of posts written.
    """
    cards = (
        db.execute(select(ProjectCard).where(ProjectCard.status == "active"))
        .scalars()
        .all()
    )
    written = 0
    for card in cards:
        if not card.repo_full_names:
            continue
        if refresh_growth(db, card, trigger="scheduled") is not None:
            written += 1
    return written
