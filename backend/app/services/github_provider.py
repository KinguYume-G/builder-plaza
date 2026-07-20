"""GitHub ingestion for the F1 Dual-Source Trust Gateway.

``GitHubDev`` fetches REAL public GitHub data by username via the unauthenticated
public REST API -- no OAuth token, so it works before the OAuth app is
registered. It sits behind the small ``GitHubProvider`` interface so a
``GitHubLive`` (per-user OAuth token, private data, higher rate limits) can drop
in later without touching the routers.
"""

from datetime import datetime, timedelta, timezone
from typing import Protocol

import httpx

from app.core.config import settings

GITHUB_API_BASE = "https://api.github.com"

# Public API without a token is rate-limited (60 req/hr/IP); keep timeouts short
# and identify ourselves, as GitHub requires a User-Agent on every request.
_TIMEOUT = 10.0
_HEADERS = {
    "Accept": "application/vnd.github+json",
    "User-Agent": "builder-plaza-trust-gateway",
}


def github_headers() -> dict:
    """Request headers, with the optional server PAT (5000 req/hr vs 60)."""
    headers = dict(_HEADERS)
    if settings.github_token:
        headers["Authorization"] = f"Bearer {settings.github_token}"
    return headers

# Activity window and event types that count toward recent_activity_count.
_ACTIVITY_WINDOW = timedelta(days=90)
_ACTIVITY_EVENT_TYPES = {"PushEvent", "PullRequestEvent", "CreateEvent"}
_TOPICS_CAP = 15


class GitHubUserNotFound(Exception):
    """The requested GitHub login does not exist (GitHub 404)."""


class GitHubAPIError(Exception):
    """GitHub was unreachable, rate-limited, or returned an unexpected status."""


class GitHubProvider(Protocol):
    def fetch(self, login: str) -> dict:
        """Return a GithubSummary-shaped dict for the given login."""
        ...


def aggregate_repos(repos: list[dict]) -> tuple[list[dict], list[str], int]:
    """Reduce a /repos payload to (top_languages, topics, stars).

    Pure so it can be unit-tested without the network. ``top_languages`` is a
    descending list of {language, count}; nulls are skipped. ``topics`` is
    deduped (order-preserving) and capped. ``stars`` sums stargazers_count.
    """
    language_counts: dict[str, int] = {}
    topics: list[str] = []
    seen_topics: set[str] = set()
    stars = 0

    for repo in repos:
        language = repo.get("language")
        if language:
            language_counts[language] = language_counts.get(language, 0) + 1

        for topic in repo.get("topics") or []:
            if topic not in seen_topics:
                seen_topics.add(topic)
                topics.append(topic)

        stars += repo.get("stargazers_count") or 0

    top_languages = [
        {"language": language, "count": count}
        for language, count in sorted(
            language_counts.items(), key=lambda item: (-item[1], item[0])
        )
    ]
    return top_languages, topics[:_TOPICS_CAP], stars


def count_recent_activity(events: list[dict], now: datetime | None = None) -> int:
    """Count relevant public events within the last 90 days.

    Pure helper: injectable ``now`` keeps the 90-day boundary testable.
    """
    now = now or datetime.now(timezone.utc)
    cutoff = now - _ACTIVITY_WINDOW
    count = 0
    for event in events:
        if event.get("type") not in _ACTIVITY_EVENT_TYPES:
            continue
        created_at = _parse_github_time(event.get("created_at"))
        if created_at is not None and created_at >= cutoff:
            count += 1
    return count


def _parse_github_time(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        # GitHub timestamps are ISO-8601 UTC, e.g. "2026-07-01T12:00:00Z".
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def fetch_repo_activity(full_name: str) -> dict:
    """Fetch light activity for one ``owner/repo`` for the F3 project card.

    Reuses GitHubDev's User-Agent/timeout against the public REST API. GRACEFUL:
    on any failure (404, rate limit, network) returns ``{"repo": full_name,
    "error": ...}`` instead of raising, so one bad repo never sinks the request.
    """
    try:
        with httpx.Client(timeout=_TIMEOUT, headers=github_headers()) as client:
            response = client.get(f"{GITHUB_API_BASE}/repos/{full_name}")
    except httpx.HTTPError as exc:
        return {"repo": full_name, "error": f"request failed: {exc}"}

    if response.status_code == 200:
        data = response.json()
        return {
            "repo": full_name,
            "html_url": data.get("html_url"),
            "stars": data.get("stargazers_count") or 0,
            "language": data.get("language"),
            "pushed_at": data.get("pushed_at"),
            "open_issues": data.get("open_issues_count") or 0,
            "description": data.get("description"),
        }
    if response.status_code == 403 and response.headers.get("X-RateLimit-Remaining") == "0":
        return {"repo": full_name, "error": "GitHub public API rate limit exceeded"}
    if response.status_code == 404:
        return {"repo": full_name, "error": "repo not found"}
    return {"repo": full_name, "error": f"GitHub API returned HTTP {response.status_code}"}


class GitHubDev:
    """Fetches real public GitHub data by username via the public REST API."""

    def fetch(self, login: str) -> dict:
        with httpx.Client(timeout=_TIMEOUT, headers=github_headers()) as client:
            user = self._get_user(client, login)
            repos = self._get_repos(client, login)
            events = self._get_events(client, login)

        top_languages, topics, stars = aggregate_repos(repos)

        return {
            "login": login,
            "name": user.get("name"),
            "avatar_url": user.get("avatar_url"),
            "public_repos": user.get("public_repos") or 0,
            "followers": user.get("followers") or 0,
            "top_languages": top_languages,
            "topics": topics,
            "recent_activity_count": count_recent_activity(events),
            "stars": stars,
        }

    def _get_user(self, client: httpx.Client, login: str) -> dict:
        response = self._request(client, f"/users/{login}")
        if response.status_code == 404:
            raise GitHubUserNotFound(login)
        self._raise_for_status(response)
        return response.json()

    def _get_repos(self, client: httpx.Client, login: str) -> list[dict]:
        response = self._request(
            client, f"/users/{login}/repos", params={"sort": "updated", "per_page": 100}
        )
        self._raise_for_status(response)
        return response.json()

    def _get_events(self, client: httpx.Client, login: str) -> list[dict]:
        response = self._request(
            client, f"/users/{login}/events/public", params={"per_page": 100}
        )
        self._raise_for_status(response)
        return response.json()

    def _request(
        self, client: httpx.Client, path: str, params: dict | None = None
    ) -> httpx.Response:
        try:
            return client.get(f"{GITHUB_API_BASE}{path}", params=params)
        except httpx.HTTPError as exc:
            raise GitHubAPIError(f"GitHub request failed: {exc}") from exc

    @staticmethod
    def _raise_for_status(response: httpx.Response) -> None:
        if response.status_code == 200:
            return
        # 403 with a zero remaining budget is the rate-limit signal.
        if response.status_code == 403 and response.headers.get("X-RateLimit-Remaining") == "0":
            raise GitHubAPIError("GitHub public API rate limit exceeded")
        raise GitHubAPIError(f"GitHub API returned HTTP {response.status_code}")
