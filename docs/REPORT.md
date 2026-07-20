# Builder Plaza — Technical Report (working draft)

> CT124-3-2-MAE Part 2. This markdown is the source draft; export to the
> submission format at the end. Sections marked ✍️ need prose written by the
> team in their own words before submission.

## 1. System overview

Builder Plaza is a trust-first collaboration marketplace for builders,
collaborators and founders. Every identity claim is backed by a verifiable
source: public GitHub records (live), LinkedIn OIDC identity (live, with a
clearly-watermarked simulated fallback per ADR-0003), peer reviews earned
through completed collaborations, and a payment-identity badge that is
**simulated and labelled as such**.

- Backend: FastAPI + SQLAlchemy + PostgreSQL (AWS RDS, pgvector), S3
  presigned uploads, Bedrock Claude Haiku summaries.
- Frontend: Flutter (iOS / Android / web), Soft Brutalist design system,
  Provider state management, go_router navigation.
- Engine: sentence-transformers MiniLM-L6-v2 (384-dim) → pgvector cosine
  recall → Gaussian Process scoring → ε-greedy exploration (ADR-0001).

## 2. Feature ↔ implementation map

| Feature | Mode | Backend | Frontend |
|---|---|---|---|
| F1 Trust Gateway | Live (GitHub + LinkedIn OIDC) / Simulated LinkedIn | `/auth/*` | onboarding steps 1–3 |
| F2 Profile + avatar + gates | Live | `/me/avatar*`, completeness | Profile tab, 40/70 gate bar |
| F3 Project Cards + Intent | Live | `/projects*`, `/me/intent` | form/detail/plaza/intent screens |
| F4 Growth Plaza | Live (GitHub + Bedrock, template fallback) | `/plaza`, `/projects/{id}/refresh-growth`, `/internal/growth-refresh-all` | Plaza GROWTH toggle, detail GROWTH section |
| F5 Matching engine | Live | `/matches*`, `/users/{id}/credibility-summary` | Matches tab, credibility sheet |
| F6 Trust Score | Live + simulated Stripe component | `/users/{id}/trust-score`, `/users/{id}/reviews` | Trust screen |
| F7 Controlled DM | Live | `/requests*`, `/conversations*` | Requests screen, conversation (10s poll) |
| F8 Request Market | Live | `/role-postings*` | Market screens |
| F9 Mocked suite | Simulated (labelled) | — | `/mocked` (sandbox/shortlist/agent/PoW) |
| F10 Verified activity + evidence | Live | `/users/{id}/activity-timeline`, `/ownership-evidence` | Evidence screen (fl_chart) |

## 3. CRUD coverage (Credit checklist)

| Entity | Create | Read | Update | Delete |
|---|---|---|---|---|
| users | GitHub connect / dev-login | `/me`, `/users/{id}/*` | role switch, avatar | — (identity kept) |
| project_cards | POST `/projects` | list/mine/detail | PATCH | soft archive |
| intents | PUT `/me/intent` | GET | PUT (replace) | DELETE |
| growth_posts | refresh-growth | `/plaza`, project growth | — (immutable log) | cascades with project |
| matches | engine writes | GET `/matches` | dismiss (state) | — |
| collab_requests | POST `/requests` | inbox/sent | accept/decline/withdraw | — (audit trail) |
| conversations/messages | accept opens; POST message | GET (poll) | — | — |
| role_postings | POST | list/detail | PATCH | soft close |
| peer_reviews | POST (accept-gated) | GET | — | — |
| avatar/screenshots (binary) | presigned PUT + register | presigned GET | replace | DELETE |

Validations: stage enum, demo URL scheme, repo `owner/repo` shape, pitch
min-20 chars, request intent enum, team_role three-mandatory-fields,
maintainer project+tier, stars 1–5, message length bounds — all rejected
server-side with structured 4xx details and surfaced inline in the UI.

## 4. Engine terminology (uniform wording)

Use exactly these names everywhere in the report: **skill embedding**
(MiniLM-L6-v2, 384-dim), **candidate recall** (pgvector cosine top-20),
**compatibility scoring** (Gaussian Process Regression on a fixed labelled
policy set), **exploration slot** (ε-greedy, ε = 0.2), **Match Reason**
(template over shared skill terms; never empty).

## 5. Mock boundary declaration (academic integrity)

Everything below is simulated, carries a visible SIMULATED label in the UI,
and never contacts the named third party:

1. LinkedIn **Simulated** mode — preset personas behind the ADR-0003
   interface (the Live OIDC mode is real; mode is switchable).
2. Stripe payment-identity badge — hardcoded, flagged `simulated: true` in
   the API; it can never carry a trust score alone (see trust_service).
3. F9 suite — contribution sandbox (scripted log replay), AI shortlist
   (preset ranking; the human approve/reject interaction is real), agent
   access panel (local state), proof-of-work challenge (animated solve).

Everything else — GitHub data, Bedrock summaries, S3 uploads, matching,
DMs, market, trust blending, activity evidence — runs live.

## 6. LinkedIn data compliance

- Only OIDC-scoped claims (sub, name, picture) are requested in Live mode;
  no scraping, no connections data.
- LinkedIn-derived fields are cached at most 48h before re-fetch on next
  login; profile embeddings use de-identified skill terms only (no names or
  contact details reach the vector store).
- The simulated mode exists so demos and automated tests NEVER hit LinkedIn.

## 7. Non-functional requirements

- **Offline read-only**: last successful plaza feed, growth feed and own
  profile are cached (shared_preferences) and served with an
  "OFFLINE · SHOWING CACHED FEED" banner when the network is unreachable.
- **Mobile adaptive**: single-column brutalist layout with max-width 620
  content wells; verified on phone-width and desktop-width viewports.
- **Rate-limit resilience**: server-side GitHub PAT (5000 req/hr), per-repo
  graceful degradation, cached user events (1h), template fallback when
  Bedrock is unavailable.

## 8. Testing

- Backend: 141 pytest cases, all pure (schema validation, growth
  normalisation/incremental boundaries, trust blending + renormalisation,
  engine determinism with fixed seeds, exploration rate ≈ ε, DM gating,
  posting validation). Run: `cd backend && python -m pytest`.
- Flutter: 13 widget/model tests (defensive parsing for all six feature
  models, shared component behaviour, boot smoke).
- E2E: `integration_test/e2e_test.dart` drives E2E-1/2/3 against a live
  local backend on the LinkedIn **Simulated** path.
- CI: `.github/workflows/ci.yml` runs pytest + flutter analyze + widget
  tests on every push. ✍️ paste coverage screenshots here.

## 9. Deployment (ADR-0002)

See `docs/DEPLOYMENT.md`: Docker (CPU-only torch, pre-baked MiniLM) → ECR →
ECS Fargate (desired = 1) behind an ALB; EventBridge calls
`/internal/growth-refresh-all` daily with a shared-secret header; secrets
injected as task environment variables.

## 10. Known limitations ✍️

- ALB listener is HTTP (no custom domain/ACM cert on the student account).
- Live LinkedIn tenure is null (OIDC exposes no employment data) — the trust
  engine renormalises weights rather than guessing.
- Messaging is 10s polling, not push — sufficient at demo scale.
