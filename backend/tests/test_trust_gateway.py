"""Pure unit tests for the F1 Trust Gateway service logic.

No DB, no network: completeness scoring, the simulated LinkedIn provider, and
GitHubDev's repo-aggregation / activity-window helpers against injected payloads.
"""

from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

from app.services import completeness
from app.services.github_provider import aggregate_repos, count_recent_activity
from app.services.identity_provider import LinkedInSimulated


def _user(github_profile=None, linkedin_sub=None, onboarding_complete=False):
    return SimpleNamespace(
        github_profile=github_profile,
        linkedin_sub=linkedin_sub,
        onboarding_complete=onboarding_complete,
        completeness_pct=0,
    )


# --- completeness.compute -------------------------------------------------

def test_completeness_empty_is_zero():
    user = _user()
    assert completeness.compute(user) == 0
    assert user.completeness_pct == 0


def test_completeness_github_only():
    assert completeness.compute(_user(github_profile={"login": "x"})) == 40


def test_completeness_linkedin_only():
    assert completeness.compute(_user(linkedin_sub="sim|ryan-tan")) == 40


def test_completeness_github_and_linkedin_not_onboarded():
    user = _user(github_profile={"login": "x"}, linkedin_sub="sim|ryan-tan")
    assert completeness.compute(user) == 80


def test_completeness_full():
    user = _user(
        github_profile={"login": "x"},
        linkedin_sub="sim|ryan-tan",
        onboarding_complete=True,
    )
    assert completeness.compute(user) == 100


# --- LinkedInSimulated ----------------------------------------------------

def test_simulated_lists_four_profiles():
    profiles = LinkedInSimulated().list_profiles()
    assert len(profiles) == 4
    # OIDC-shaped claims present on every preset.
    for p in profiles:
        assert {"id", "sub", "name", "headline", "tenure_years"} <= p.keys()


def test_simulated_get_profile_round_trips():
    provider = LinkedInSimulated()
    profile = provider.get_profile("li_ryan")
    assert profile is not None
    assert profile["sub"] == "sim|ryan-tan"
    assert profile["tenure_years"] == 4


def test_simulated_get_profile_unknown_returns_none():
    assert LinkedInSimulated().get_profile("li_nobody") is None


def test_simulated_list_profiles_is_defensive_copy():
    provider = LinkedInSimulated()
    provider.list_profiles()[0]["name"] = "MUTATED"
    assert provider.list_profiles()[0]["name"] == "Ryan Tan"


# --- GitHubDev.aggregate_repos --------------------------------------------

def test_aggregate_repos_counts_languages_descending():
    repos = [
        {"language": "Python", "topics": [], "stargazers_count": 5},
        {"language": "Python", "topics": [], "stargazers_count": 1},
        {"language": "Dart", "topics": [], "stargazers_count": 2},
        {"language": None, "topics": [], "stargazers_count": 0},
    ]
    top_languages, topics, stars = aggregate_repos(repos)

    assert top_languages == [
        {"language": "Python", "count": 2},
        {"language": "Dart", "count": 1},
    ]
    assert topics == []
    assert stars == 8


def test_aggregate_repos_dedups_and_caps_topics():
    repos = [
        {"language": "Go", "topics": [f"t{i}" for i in range(10)], "stargazers_count": 0},
        {"language": "Go", "topics": ["t0", "t1", "extra1", "extra2", "extra3", "extra4",
                                      "extra5", "extra6"], "stargazers_count": 0},
    ]
    _, topics, _ = aggregate_repos(repos)

    assert len(topics) == 15  # capped
    assert len(topics) == len(set(topics))  # deduped
    assert topics[0] == "t0"


def test_aggregate_repos_handles_missing_fields():
    top_languages, topics, stars = aggregate_repos([{}, {"language": "Rust"}])
    assert top_languages == [{"language": "Rust", "count": 1}]
    assert topics == []
    assert stars == 0


# --- GitHubDev.count_recent_activity --------------------------------------

def test_count_recent_activity_filters_type_and_window():
    now = datetime(2026, 7, 20, tzinfo=timezone.utc)
    events = [
        {"type": "PushEvent", "created_at": "2026-07-01T00:00:00Z"},        # in window
        {"type": "PullRequestEvent", "created_at": "2026-06-01T00:00:00Z"}, # in window
        {"type": "CreateEvent", "created_at": "2026-07-19T00:00:00Z"},      # in window
        {"type": "WatchEvent", "created_at": "2026-07-19T00:00:00Z"},       # wrong type
        {"type": "PushEvent", "created_at": "2026-01-01T00:00:00Z"},        # too old
    ]
    assert count_recent_activity(events, now=now) == 3


def test_count_recent_activity_ninety_day_boundary():
    now = datetime(2026, 7, 20, tzinfo=timezone.utc)
    on_edge = (now - timedelta(days=89)).isoformat().replace("+00:00", "Z")
    just_over = (now - timedelta(days=91)).isoformat().replace("+00:00", "Z")
    events = [
        {"type": "PushEvent", "created_at": on_edge},
        {"type": "PushEvent", "created_at": just_over},
    ]
    assert count_recent_activity(events, now=now) == 1
