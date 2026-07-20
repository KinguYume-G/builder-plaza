"""Pure unit tests for F3 Project Card + Intent schema/service logic.

No DB, no network, no S3: schema validation, content-type -> extension mapping,
and the screenshot S3 key shape.
"""

import uuid

import pytest
from pydantic import ValidationError

from app.schemas.intent import IntentIn
from app.schemas.project import (
    STAGES,
    ProjectCreateIn,
    ProjectUpdateIn,
    ScreenshotUrlIn,
)
from app.services import s3_service


# --- stage validation -----------------------------------------------------

@pytest.mark.parametrize("stage", STAGES)
def test_stage_accepts_valid(stage):
    assert ProjectCreateIn(title="X", stage=stage).stage == stage


def test_stage_rejects_invalid():
    with pytest.raises(ValidationError):
        ProjectCreateIn(title="X", stage="prod")


# --- demo_url validation --------------------------------------------------

@pytest.mark.parametrize("url", ["http://x.io", "https://a.b/c?d=1", None])
def test_demo_url_accepts_valid(url):
    assert ProjectCreateIn(title="X", stage="idea", demo_url=url).demo_url == url


@pytest.mark.parametrize("url", ["ftp://x.io", "notaurl", "http://", "/relative"])
def test_demo_url_rejects_invalid(url):
    with pytest.raises(ValidationError):
        ProjectCreateIn(title="X", stage="idea", demo_url=url)


# --- repo_full_names validation -------------------------------------------

def test_repos_accept_valid():
    repos = ["octocat/Hello-World", "a.b/c-d"]
    assert ProjectCreateIn(title="X", stage="idea", repo_full_names=repos).repo_full_names == repos


@pytest.mark.parametrize("repos", [["noslash"], ["a/b/c"], ["/x"], ["x/"]])
def test_repos_reject_bad_shape(repos):
    with pytest.raises(ValidationError):
        ProjectCreateIn(title="X", stage="idea", repo_full_names=repos)


def test_repos_reject_over_cap():
    with pytest.raises(ValidationError):
        ProjectCreateIn(title="X", stage="idea", repo_full_names=[f"o/r{i}" for i in range(11)])


# --- title bounds ---------------------------------------------------------

def test_title_required_nonempty():
    with pytest.raises(ValidationError):
        ProjectCreateIn(title="", stage="idea")


def test_title_max_length():
    with pytest.raises(ValidationError):
        ProjectCreateIn(title="x" * 121, stage="idea")


# --- ProjectUpdateIn ------------------------------------------------------

def test_update_all_optional():
    assert ProjectUpdateIn().model_dump(exclude_unset=True) == {}


def test_update_status_choices():
    assert ProjectUpdateIn(status="archived").status == "archived"
    with pytest.raises(ValidationError):
        ProjectUpdateIn(status="deleted")


def test_update_validates_stage_when_present():
    with pytest.raises(ValidationError):
        ProjectUpdateIn(stage="bogus")


# --- content_type -> ext mapping + rejection ------------------------------

@pytest.mark.parametrize(
    "content_type,ext",
    [("image/jpeg", "jpg"), ("image/png", "png"), ("image/webp", "webp")],
)
def test_content_type_to_ext(content_type, ext):
    assert s3_service.ext_for_content_type(content_type) == ext


def test_content_type_unsupported_returns_none():
    assert s3_service.ext_for_content_type("image/gif") is None


def test_screenshot_url_in_rejects_bad_content_type():
    ScreenshotUrlIn(content_type="image/png")  # ok
    with pytest.raises(ValidationError):
        ScreenshotUrlIn(content_type="image/gif")


# --- s3 key pattern shape -------------------------------------------------

def test_screenshot_key_shape():
    project_id = uuid.uuid4()
    key = s3_service.screenshot_key(project_id, "image/png")
    prefix = f"screenshots/{project_id}/"
    assert key.startswith(prefix)
    assert key.endswith(".png")
    # the middle segment is a parseable uuid4
    middle = key[len(prefix):-len(".png")]
    assert uuid.UUID(middle).version == 4


# --- intent_type validation -----------------------------------------------

@pytest.mark.parametrize(
    "intent_type",
    ["seeking_cofounder", "seeking_maintainer", "open_to_chat", "not_open"],
)
def test_intent_type_accepts_valid(intent_type):
    assert IntentIn(intent_type=intent_type).intent_type == intent_type


def test_intent_type_rejects_invalid():
    with pytest.raises(ValidationError):
        IntentIn(intent_type="looking")


def test_intent_note_max_length():
    with pytest.raises(ValidationError):
        IntentIn(intent_type="open_to_chat", note="x" * 501)
