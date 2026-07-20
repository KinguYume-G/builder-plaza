"""Pure unit tests for F4 Growth Plaza: event normalisation, incremental
filtering, and the Bedrock fallback template. No DB, no network."""

from datetime import datetime, timezone

from app.services import bedrock_service, growth_service


def _raw(event_type="PushEvent", created_at="2026-07-19T12:00:00Z", payload=None, actor="octocat"):
    return {
        "type": event_type,
        "created_at": created_at,
        "actor": {"login": actor},
        "payload": payload or {},
    }


SINCE = datetime(2026, 7, 1, tzinfo=timezone.utc)


# --- normalize_event ------------------------------------------------------

def test_normalize_push_event():
    raw = _raw(payload={"commits": [{"message": "fix: everything works now"}]})
    out = growth_service.normalize_event(raw, "octocat/hello")
    assert out["type"] == "PushEvent"
    assert out["repo"] == "octocat/hello"
    assert out["actor"] == "octocat"
    assert "1 commit(s)" in out["detail"]
    assert "fix: everything" in out["detail"]


def test_normalize_pr_event():
    raw = _raw(
        "PullRequestEvent",
        payload={"action": "opened", "pull_request": {"title": "Add plaza feed"}},
    )
    out = growth_service.normalize_event(raw, "a/b")
    assert out["detail"] == "opened PR: Add plaza feed"


def test_normalize_release_event():
    raw = _raw("ReleaseEvent", payload={"release": {"tag_name": "v1.2.0"}})
    assert growth_service.normalize_event(raw, "a/b")["detail"] == "release v1.2.0"


def test_normalize_create_event():
    raw = _raw("CreateEvent", payload={"ref_type": "branch", "ref": "feat/x"})
    assert growth_service.normalize_event(raw, "a/b")["detail"] == "created branch feat/x"


# --- filter_new_events (incremental boundary) -----------------------------

def test_filter_keeps_only_newer_than_since():
    raws = [
        _raw(created_at="2026-07-19T12:00:00Z"),  # newer -> kept
        _raw(created_at="2026-07-01T00:00:00Z"),  # exactly since -> dropped
        _raw(created_at="2026-06-01T00:00:00Z"),  # older -> dropped
    ]
    kept = growth_service.filter_new_events(raws, "a/b", SINCE)
    assert len(kept) == 1
    assert kept[0]["created_at"] == "2026-07-19T12:00:00Z"


def test_filter_drops_non_growth_types():
    raws = [_raw("WatchEvent"), _raw("ForkEvent"), _raw("PushEvent")]
    kept = growth_service.filter_new_events(raws, "a/b", SINCE)
    assert [event["type"] for event in kept] == ["PushEvent"]


def test_filter_drops_unparseable_timestamps():
    raws = [_raw(created_at="not-a-date"), _raw(created_at=None)]
    assert growth_service.filter_new_events(raws, "a/b", SINCE) == []


# --- fallback template ----------------------------------------------------

def test_fallback_summary_counts_by_type():
    events = [
        {"type": "PushEvent", "repo": "a/b"},
        {"type": "PushEvent", "repo": "a/b"},
        {"type": "ReleaseEvent", "repo": "a/c"},
    ]
    summary = bedrock_service.fallback_summary("Demo", events)
    assert "Demo" in summary
    assert "3 recent GitHub event(s)" in summary
    assert "2 push(es)" in summary
    assert "1 release(s)" in summary
    assert "a/b" in summary and "a/c" in summary


def test_fallback_summary_empty_events():
    summary = bedrock_service.fallback_summary("Demo", [])
    assert "0 recent GitHub event(s)" in summary


# --- summarize_events degrades on Bedrock failure -------------------------

def test_summarize_falls_back_when_bedrock_raises(monkeypatch):
    def boom():
        raise RuntimeError("no creds")

    monkeypatch.setattr(bedrock_service, "_bedrock", boom)
    events = [{"type": "PushEvent", "repo": "a/b"}]
    summary, used_llm = bedrock_service.summarize_events("Demo", events)
    assert used_llm is False
    assert "Demo" in summary


def test_summarize_uses_llm_text(monkeypatch):
    class FakeBody:
        def read(self):
            return b'{"content": [{"type": "text", "text": "Neutral summary."}]}'

    class FakeClient:
        def invoke_model(self, **kwargs):
            return {"body": FakeBody()}

    monkeypatch.setattr(bedrock_service, "_bedrock", lambda: FakeClient())
    summary, used_llm = bedrock_service.summarize_events("Demo", [{"type": "PushEvent"}])
    assert used_llm is True
    assert summary == "Neutral summary."
