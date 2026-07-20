"""F10 Verified Activity + Ownership Evidence.

The timeline and evidence views are built from the user's public GitHub
events and repo list. Events are cached on the user row (users.github_events,
migration 0003) with a freshness window, so repeat views serve stored data;
when GitHub is unreachable the stale cache (or an empty list) is served
instead of an error -- evidence must degrade, never 500.
"""

from datetime import datetime, timedelta, timezone

import httpx
from sqlalchemy.orm import Session

from app.db.models import User
from app.services.github_provider import (
    GITHUB_API_BASE,
    _TIMEOUT,
    _parse_github_time,
    github_headers,
)

# Event types shown on the Verified Activity timeline.
_TIMELINE_EVENT_TYPES = {
    "PushEvent",
    "PullRequestEvent",
    "CreateEvent",
    "ReleaseEvent",
    "IssuesEvent",
}

# Serve the cached events if they are younger than this.
_CACHE_MAX_AGE = timedelta(hours=1)

# Continuity chart window (GitHub's public events feed covers ~90 days).
_EVIDENCE_WEEKS = 12


def normalize_user_event(raw: dict) -> dict | None:
    """Reduce one raw /users/{login}/events item to a timeline entry.

    Pure. Returns None for event types that don't belong on the timeline.
    """
    event_type = raw.get("type")
    if event_type not in _TIMELINE_EVENT_TYPES:
        return None
    payload = raw.get("payload") or {}
    detail = None
    if event_type == "PushEvent":
        commits = payload.get("commits") or []
        # The events API sometimes omits the commits list; "size" still counts.
        count = len(commits) or payload.get("size") or 0
        detail = f"pushed {count} commit(s)"
        if commits:
            detail += f": {commits[-1].get('message', '')[:80]}"
    elif event_type == "PullRequestEvent":
        pr = payload.get("pull_request") or {}
        detail = f"{payload.get('action', '')} PR: {pr.get('title', '')[:80]}"
        if payload.get("action") == "closed" and pr.get("merged"):
            detail = f"merged PR: {pr.get('title', '')[:80]}"
    elif event_type == "CreateEvent":
        detail = f"created {payload.get('ref_type', '')} {payload.get('ref') or ''}".strip()
    elif event_type == "ReleaseEvent":
        release = payload.get("release") or {}
        detail = f"published release {release.get('tag_name', '')}"
    elif event_type == "IssuesEvent":
        issue = payload.get("issue") or {}
        detail = f"{payload.get('action', '')} issue: {issue.get('title', '')[:80]}"

    return {
        "type": event_type,
        "repo": (raw.get("repo") or {}).get("name"),
        "created_at": raw.get("created_at"),
        "detail": detail,
    }


def normalize_user_events(raw_events: list[dict]) -> list[dict]:
    """Pure: normalise + drop irrelevant types, keeping GitHub's newest-first order."""
    out = []
    for raw in raw_events:
        item = normalize_user_event(raw)
        if item is not None:
            out.append(item)
    return out


def _fetch_events(login: str) -> list[dict] | None:
    """Fetch raw public events; None on any failure (caller falls back to cache)."""
    try:
        with httpx.Client(timeout=_TIMEOUT, headers=github_headers()) as client:
            response = client.get(
                f"{GITHUB_API_BASE}/users/{login}/events/public",
                params={"per_page": 100},
            )
    except httpx.HTTPError:
        return None
    if response.status_code != 200:
        return None
    return response.json()


def get_user_events(db: Session, user: User, now: datetime | None = None) -> list[dict]:
    """Return the user's normalised events, refreshing the cache when stale."""
    now = now or datetime.now(timezone.utc)
    fetched_at = user.github_events_fetched_at
    if (
        user.github_events is not None
        and fetched_at is not None
        and now - fetched_at < _CACHE_MAX_AGE
    ):
        return list(user.github_events)

    raw = _fetch_events(user.github_login)
    if raw is None:
        # GitHub unavailable: serve whatever we have stored (possibly empty).
        return list(user.github_events or [])

    events = normalize_user_events(raw)
    user.github_events = events
    user.github_events_fetched_at = now
    db.commit()
    return events


def weekly_activity(events: list[dict], now: datetime | None = None) -> list[dict]:
    """Pure: bucket events into the last ``_EVIDENCE_WEEKS`` ISO weeks.

    Returns oldest-first [{week_start: iso date, count}] so the chart reads
    left→right chronologically. Continuity = how many buckets are non-zero.
    """
    now = now or datetime.now(timezone.utc)
    # Normalise to the Monday of the current week.
    this_monday = (now - timedelta(days=now.weekday())).date()
    week_starts = [
        this_monday - timedelta(weeks=offset)
        for offset in range(_EVIDENCE_WEEKS - 1, -1, -1)
    ]
    counts = {week_start: 0 for week_start in week_starts}
    for event in events:
        created_at = _parse_github_time(event.get("created_at"))
        if created_at is None:
            continue
        monday = (created_at - timedelta(days=created_at.weekday())).date()
        if monday in counts:
            counts[monday] += 1
    return [
        {"week_start": week_start.isoformat(), "count": counts[week_start]}
        for week_start in week_starts
    ]


def classify_repo_roles(repos: list[dict], login: str) -> list[dict]:
    """Pure: reduce a /users/{login}/repos payload to ownership-role entries.

    role: "owner" for source repos the user owns, "fork-maintainer" for forks.
    Sorted by stars desc then recency; capped to keep the payload small.
    """
    entries = []
    for repo in repos:
        entries.append(
            {
                "repo": repo.get("full_name"),
                "role": "fork-maintainer" if repo.get("fork") else "owner",
                "stars": repo.get("stargazers_count") or 0,
                "language": repo.get("language"),
                "pushed_at": repo.get("pushed_at"),
            }
        )
    entries.sort(key=lambda entry: (-entry["stars"], entry["pushed_at"] or ""), reverse=False)
    return entries[:10]


def fetch_repo_roles(login: str) -> list[dict]:
    """Live repo list → roles; empty list on any failure (graceful)."""
    try:
        with httpx.Client(timeout=_TIMEOUT, headers=github_headers()) as client:
            response = client.get(
                f"{GITHUB_API_BASE}/users/{login}/repos",
                params={"sort": "pushed", "per_page": 100},
            )
    except httpx.HTTPError:
        return []
    if response.status_code != 200:
        return []
    return classify_repo_roles(response.json(), login)
