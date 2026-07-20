"""Regression: GitHubDev.fetch must return GitHub's CANONICAL login (not the
raw typed string), so differently-cased logins don't create duplicate users
and break LinkedIn binding."""

from app.services.github_provider import GitHubDev


class _FakeResp:
    def __init__(self, payload):
        self._payload = payload
        self.status_code = 200

    def json(self):
        return self._payload


def test_fetch_uses_canonical_login(monkeypatch):
    # GitHub resolves /users/SUNFLOWERSLWTECH but returns canonical casing.
    def fake_get_user(self, client, login):
        return {"login": "sunflowerslwtech", "name": "SunFlowers", "public_repos": 3}

    monkeypatch.setattr(GitHubDev, "_get_user", fake_get_user)
    monkeypatch.setattr(GitHubDev, "_get_repos", lambda self, c, l: [])
    monkeypatch.setattr(GitHubDev, "_get_events", lambda self, c, l: [])
    monkeypatch.setattr(
        "app.services.github_provider.httpx.Client",
        lambda *a, **k: type("C", (), {"__enter__": lambda s: s, "__exit__": lambda *x: False})(),
    )

    summary = GitHubDev().fetch("SUNFLOWERSLWTECH")  # typed in caps
    assert summary["login"] == "sunflowerslwtech"  # canonical, not the input
