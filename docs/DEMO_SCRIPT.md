# Demo video script (§8.2 one-take walkthrough)

Before recording: `cd backend && .venv/bin/python seed.py` (resets to the
known initial state), backend reachable (local or the ALB URL).

| # | Beat | Where | Say / show |
|---|---|---|---|
| 1 | Trust Gateway | fresh app | Enter a real GitHub username → live repos/languages/stars appear. "Nothing here is self-reported." |
| 2 | Simulated LinkedIn | Step 2 | Point at the SIMULATED FOR DEMO watermark — academic-integrity labelling; mention the real OIDC Live mode exists behind the same interface (ADR-0003). |
| 3 | Role lens | Step 3 | Pick Builder → Builder Home. |
| 4 | Profile + gates | Profile tab | Completeness bar with 40/70 gate ticks; tap avatar → upload (S3 presigned, image binary requirement). |
| 5 | Project card | Home → ＋ New project | Create with a real repo; show live repo activity on the detail page. |
| 6 | Growth Plaza | project detail → Refresh growth | Bedrock Haiku writes a neutral update; show it in Plaza → GROWTH feed. Mention the template fallback + daily scheduled path. |
| 7 | Evidence | Profile → Verified activity & evidence | Continuity chart + repository roles + typed timeline. |
| 8 | Trust score | Profile → Trust score | Component bars, weights, the SIMULATED Stripe badge (which can never carry the score alone). |
| 9 | Matching | Match tab | Cards with WHY reasons; point at the EXPLORE badge; pull-to-refresh changes the exploration slot. Open Credibility → plain-language summary for non-technical users. |
| 10 | Controlled DM | Credibility → Request collaboration | Structured intent + pitch (min 20 chars). Switch account (dev-login as the recipient) → accept → conversation opens → exchange messages (10s poll). |
| 11 | Peer review | after accept | Review the counterpart → trust score updates. |
| 12 | Request market | Home → Request market | Both posting types; team_role three-mandatory validation (try submitting empty); Apply reuses the request pipeline. |
| 13 | Mocked suite | Profile → Simulated suite | Sandbox log replay, human-approve shortlist, agent scopes, PoW — all labelled SIMULATED. |
| 14 | Offline NFR | toggle network off | Plaza still renders with OFFLINE · SHOWING CACHED FEED. |
| 15 | Close | terminal | `pytest` green (141), `flutter test` green (13), CI badge, ALB /health in the browser. |
