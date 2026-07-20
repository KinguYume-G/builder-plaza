"""F9 Mocked capability endpoints (PRD §5.2 interface shapes).

Every payload is SIMULATED demo data and says so explicitly with
``"simulated": true`` — the same academic-integrity labelling the UI carries.
The Flutter mocked suite currently renders equivalent hardcoded data; these
endpoints exist so the declared API surface matches the PRD.
"""

from fastapi import APIRouter, Depends

from app.core.security import get_current_user
from app.db.models import User

router = APIRouter(tags=["mocked"])

_SANDBOX_LOG = [
    {"line": "$ sandbox init --repo wave5-demo/growth --tier claim_an_issue", "kind": "cmd"},
    {"line": "sandbox: provisioning ephemeral container (simulated)", "kind": "out"},
    {"line": "sandbox: cloning repository… done (2.1s)", "kind": "out"},
    {"line": "$ pytest -q", "kind": "cmd"},
    {"line": "..................... 21 passed in 3.4s", "kind": "out"},
    {"line": "$ sandbox permissions", "kind": "cmd"},
    {"line": "read: src/**  write: src/features/growth/**  network: DENIED", "kind": "out"},
    {"line": "sandbox: candidate changes isolated from main branch", "kind": "out"},
    {"line": "sandbox: session recorded for maintainer review", "kind": "out"},
    {"line": "— end of simulated log —", "kind": "out"},
]

_SHORTLIST = [
    {
        "login": "aisha-r",
        "role": "collaborator",
        "rationale": "Strong Postgres history; 9/12 active weeks; 4.8★ peer average.",
        "state": "pending",
    },
    {
        "login": "mei-designs",
        "role": "collaborator",
        "rationale": "Design-system portfolio matches your Soft Brutalist direction.",
        "state": "pending",
    },
    {
        "login": "marcus-cto",
        "role": "founder",
        "rationale": "Fintech domain overlap; hiring history suggests team fit.",
        "state": "pending",
    },
]


@router.get("/founder/shortlist/ai")
def ai_shortlist(_viewer: User = Depends(get_current_user)) -> dict:
    """Preset AI ranking. The human approve/reject step happens client-side;
    the AI never auto-contacts anyone."""
    return {"simulated": True, "note": "Preset demo ranking — not a live model.",
            "candidates": _SHORTLIST}


@router.get("/sandbox/demo-log")
def sandbox_demo_log(_viewer: User = Depends(get_current_user)) -> dict:
    """The scripted contribution-sandbox session replay. No code is executed."""
    return {"simulated": True, "note": "Scripted replay — no code is executed.",
            "lines": _SANDBOX_LOG}


@router.get("/me/agent-access")
def agent_access(_viewer: User = Depends(get_current_user)) -> dict:
    """The scopes an AI agent WOULD get on the user's behalf. No agent exists."""
    return {
        "simulated": True,
        "note": "Demo scope panel — no agent is connected.",
        "scopes": [
            {"scope": "read_project_cards", "granted": True},
            {"scope": "draft_growth_updates", "granted": True},
            {"scope": "reply_collab_requests", "granted": False},
            {"scope": "publish_role_postings", "granted": False},
        ],
        "audit": "Every agent action would be logged and human-reviewable.",
    }


@router.post("/pow-challenge")
def pow_challenge(_viewer: User = Depends(get_current_user)) -> dict:
    """Anti-spam proof-of-work gate. The demo returns a fixed pre-solved
    challenge; nothing is mined client- or server-side."""
    return {
        "simulated": True,
        "challenge": 'sha256(nonce + "builder-plaza") < 2^236',
        "difficulty": 20,
        "solved_nonce": "0x2f9a11",
        "verified": True,
        "note": "Pre-solved demo challenge — no hashing performed.",
    }
