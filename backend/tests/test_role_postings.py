"""Pure unit tests for F8 Request Market validation: the two posting types'
required-field rules (team_role's three-mandatory rule, maintainer's
project + access_tier rule)."""

import uuid

import pytest
from pydantic import ValidationError

from app.schemas.role_posting import RolePostingIn

PROJECT_ID = uuid.uuid4()
DESC = "Looking for a Flutter dev to own the mobile client."


# --- team_role: three mandatory fields ------------------------------------

def test_team_role_valid_with_all_three():
    posting = RolePostingIn(
        posting_type="team_role",
        role_desc=DESC,
        stage="mvp",
        tech_stack="Flutter + FastAPI",
        commitment="10h/week",
    )
    assert posting.posting_type == "team_role"


@pytest.mark.parametrize(
    "missing", ["stage", "tech_stack", "commitment"]
)
def test_team_role_missing_any_mandatory_field_fails(missing):
    fields = {
        "stage": "mvp",
        "tech_stack": "Flutter",
        "commitment": "10h/week",
    }
    fields[missing] = None
    with pytest.raises(ValidationError, match=missing):
        RolePostingIn(posting_type="team_role", role_desc=DESC, **fields)


def test_team_role_blank_string_counts_as_missing():
    with pytest.raises(ValidationError, match="tech_stack"):
        RolePostingIn(
            posting_type="team_role",
            role_desc=DESC,
            stage="mvp",
            tech_stack="   ",
            commitment="10h/week",
        )


# --- maintainer: project + access tier ------------------------------------

def test_maintainer_valid():
    posting = RolePostingIn(
        posting_type="maintainer",
        role_desc=DESC,
        project_id=PROJECT_ID,
        access_tier="claim_an_issue",
    )
    assert posting.access_tier == "claim_an_issue"


def test_maintainer_requires_project():
    with pytest.raises(ValidationError, match="project"):
        RolePostingIn(
            posting_type="maintainer", role_desc=DESC, access_tier="full"
        )


def test_maintainer_requires_valid_access_tier():
    with pytest.raises(ValidationError, match="access_tier"):
        RolePostingIn(
            posting_type="maintainer",
            role_desc=DESC,
            project_id=PROJECT_ID,
            access_tier="root",
        )


# --- general --------------------------------------------------------------

def test_unknown_posting_type_rejected():
    with pytest.raises(ValidationError, match="posting_type"):
        RolePostingIn(posting_type="internship", role_desc=DESC)


def test_role_desc_must_be_substantive():
    with pytest.raises(ValidationError):
        RolePostingIn(
            posting_type="team_role",
            role_desc="dev pls",
            stage="mvp",
            tech_stack="Flutter",
            commitment="10h",
        )
