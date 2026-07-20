"""F4 Growth Plaza: LLM summarisation of GitHub event batches via Bedrock.

Claude Haiku turns a batch of raw GitHub events into one neutral, factual
growth update. The prompt is FIXED here (not user-supplied) so summaries stay
consistent and non-promotional. On ANY Bedrock failure we degrade to a plain
template built from event counts -- a growth post must never fail to be
written just because the LLM was unavailable (F4 acceptance criteria).
"""

import json

import boto3
from botocore.config import Config

from app.core.config import settings

_client = None

# Keep the summary short and neutral. The events are passed as compact JSON;
# Haiku is instructed to describe only what is in them.
_SYSTEM_PROMPT = (
    "You write short, neutral progress updates for a software project feed. "
    "You are given a JSON list of recent GitHub events for the project's "
    "repositories. Write ONE factual summary paragraph (2-3 sentences, max 80 "
    "words) of what happened, in third person, no hype, no emojis, no "
    "adjectives like 'amazing'. Mention concrete things: commits pushed, pull "
    "requests opened/merged, releases, new branches. Do not invent anything "
    "not present in the events."
)


def _bedrock():
    """Lazily build (and memoise) the bedrock-runtime client from explicit
    creds, mirroring s3_service (the builderplaza account, not the ambient
    default profile)."""
    global _client
    if _client is None:
        _client = boto3.client(
            "bedrock-runtime",
            aws_access_key_id=settings.aws_access_key_id,
            aws_secret_access_key=settings.aws_secret_access_key,
            region_name=settings.aws_region,
            config=Config(read_timeout=30, retries={"max_attempts": 1}),
        )
    return _client


def fallback_summary(project_title: str, events: list[dict]) -> str:
    """Deterministic template used when Bedrock is unavailable.

    Pure (no network) so it is unit-testable and always succeeds.
    """
    counts: dict[str, int] = {}
    repos: list[str] = []
    for event in events:
        counts[event.get("type", "other")] = counts.get(event.get("type", "other"), 0) + 1
        repo = event.get("repo")
        if repo and repo not in repos:
            repos.append(repo)

    parts = []
    label_map = {
        "PushEvent": "push(es)",
        "PullRequestEvent": "pull request update(s)",
        "CreateEvent": "new branch/tag creation(s)",
        "ReleaseEvent": "release(s)",
        "IssuesEvent": "issue update(s)",
    }
    for event_type, count in sorted(counts.items(), key=lambda item: (-item[1], item[0])):
        parts.append(f"{count} {label_map.get(event_type, event_type)}")

    activity = ", ".join(parts) if parts else "no categorised activity"
    repo_str = ", ".join(repos[:3]) if repos else "its repositories"
    return (
        f"{project_title} logged {len(events)} recent GitHub event(s) across "
        f"{repo_str}: {activity}."
    )


def summarize_events(project_title: str, events: list[dict]) -> tuple[str, bool]:
    """Return (summary, used_llm).

    used_llm=False means the deterministic fallback template was used.
    """
    try:
        body = json.dumps(
            {
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 300,
                "system": _SYSTEM_PROMPT,
                "messages": [
                    {
                        "role": "user",
                        "content": (
                            f"Project: {project_title}\n"
                            f"Events JSON:\n{json.dumps(events, default=str)}"
                        ),
                    }
                ],
            }
        )
        response = _bedrock().invoke_model(
            modelId=settings.bedrock_model_id,
            contentType="application/json",
            accept="application/json",
            body=body,
        )
        payload = json.loads(response["body"].read())
        text = "".join(
            block.get("text", "") for block in payload.get("content", [])
        ).strip()
        if text:
            return text, True
    except Exception:
        # Any Bedrock/network/parse failure falls through to the template.
        pass
    return fallback_summary(project_title, events), False
