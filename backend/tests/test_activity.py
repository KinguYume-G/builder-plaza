"""Pure unit tests for F10 Verified Activity + Ownership Evidence:
event normalisation, weekly bucketing, and repo-role classification."""

from datetime import datetime, timezone

from app.services import activity_service


def _raw(event_type="PushEvent", created_at="2026-07-18T12:00:00Z", payload=None):
    return {
        "type": event_type,
        "created_at": created_at,
        "repo": {"name": "octocat/hello"},
        "payload": payload or {},
    }


NOW = datetime(2026, 7, 20, 12, 0, tzinfo=timezone.utc)  # a Monday


# --- normalize_user_event -------------------------------------------------

def test_normalize_push():
    item = activity_service.normalize_user_event(
        _raw(payload={"commits": [{"message": "add plaza"}]})
    )
    assert item["type"] == "PushEvent"
    assert item["repo"] == "octocat/hello"
    assert "pushed 1 commit(s)" in item["detail"]


def test_normalize_merged_pr():
    item = activity_service.normalize_user_event(
        _raw(
            "PullRequestEvent",
            payload={
                "action": "closed",
                "pull_request": {"title": "Fix bug", "merged": True},
            },
        )
    )
    assert item["detail"] == "merged PR: Fix bug"


def test_normalize_drops_watch_events():
    assert activity_service.normalize_user_event(_raw("WatchEvent")) is None


def test_normalize_user_events_keeps_order_and_filters():
    events = activity_service.normalize_user_events(
        [_raw(created_at="2026-07-18T12:00:00Z"), _raw("ForkEvent"), _raw("ReleaseEvent")]
    )
    assert [event["type"] for event in events] == ["PushEvent", "ReleaseEvent"]


# --- weekly_activity ------------------------------------------------------

def test_weekly_activity_buckets_into_correct_weeks():
    events = [
        {"created_at": "2026-07-20T09:00:00Z"},  # this week (Mon 2026-07-20)
        {"created_at": "2026-07-15T09:00:00Z"},  # last week (Mon 2026-07-13)
        {"created_at": "2026-07-13T00:30:00Z"},  # last week boundary
        {"created_at": "2026-01-01T00:00:00Z"},  # far outside the window
    ]
    weekly = activity_service.weekly_activity(events, now=NOW)
    assert len(weekly) == 12
    assert weekly[-1] == {"week_start": "2026-07-20", "count": 1}
    assert weekly[-2] == {"week_start": "2026-07-13", "count": 2}
    assert all(bucket["count"] == 0 for bucket in weekly[:-2])


def test_weekly_activity_is_chronological():
    weekly = activity_service.weekly_activity([], now=NOW)
    starts = [bucket["week_start"] for bucket in weekly]
    assert starts == sorted(starts)


# --- classify_repo_roles --------------------------------------------------

def test_classify_repo_roles_owner_vs_fork():
    repos = [
        {"full_name": "me/source", "fork": False, "stargazers_count": 5},
        {"full_name": "me/forked", "fork": True, "stargazers_count": 50},
    ]
    roles = activity_service.classify_repo_roles(repos, "me")
    by_repo = {entry["repo"]: entry["role"] for entry in roles}
    assert by_repo == {"me/source": "owner", "me/forked": "fork-maintainer"}


def test_classify_repo_roles_caps_at_ten():
    repos = [
        {"full_name": f"me/r{i}", "fork": False, "stargazers_count": i} for i in range(15)
    ]
    assert len(activity_service.classify_repo_roles(repos, "me")) == 10
