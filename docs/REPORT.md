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
- **Mobile adaptive**: `HomeShell` switches its primary navigation chrome by
  viewport width — a bottom navigation bar below 700px (phones), a side rail
  above it (tablet/desktop/web), both sharing the same four destinations and
  brutalist visual language (`kWideLayoutBreakpoint` in `home_shell.dart`).
  Covered by two widget tests (`test/responsive_test.dart`) that pump the
  shell at both widths and assert on the rendered layout.
- **Rate-limit resilience**: server-side GitHub PAT (5000 req/hr), per-repo
  graceful degradation, cached user events (1h), template fallback when
  Bedrock is unavailable.

## 8. Testing

- Backend: **171 pytest cases** — 141 pure unit tests (schema validation,
  growth normalisation/incremental boundaries, trust blending +
  renormalisation, engine determinism with fixed seeds, exploration rate ≈ ε,
  DM gating, posting validation) plus **30 API integration tests**
  (`tests/test_integration_*.py`, added 2026-07-20) that drive real routes
  through FastAPI's `TestClient` against a real Postgres+pgvector database —
  auth gating (missing/expired/forged/deleted-user tokens), Project Card
  CRUD + ownership (cross-user PATCH is rejected), the Collaboration Request
  → accept → conversation → message state machine including the negative
  cases from the test plan (self-request, duplicate-pending, non-participant
  read), and Request Market maintainer/team_role validation. Isolated per
  test via a rolled-back transaction (SQLAlchemy `create_savepoint` join
  mode) against a throwaway local DB (`docker-compose.yml`), never the
  shared dev/demo RDS instance. Run: `cd backend && docker compose up -d &&
  python -m pytest`.
- Flutter: **15 widget/model tests** (defensive parsing for all six feature
  models, shared component behaviour, boot smoke, plus 2 responsive-layout
  tests added 2026-07-20 asserting the bottom-nav/side-rail switch at the
  700px breakpoint).
- E2E: `integration_test/e2e_test.dart` drives E2E-1/2/3 against a live
  local backend on the LinkedIn **Simulated** path.
- CI: `.github/workflows/ci.yml` runs pytest (now including the integration
  layer, against a Postgres service container) + flutter analyze + widget
  tests on every push. ✍️ paste coverage screenshots here.

## 9. Deployment (ADR-0002)

See `docs/DEPLOYMENT.md`: Docker (CPU-only torch, pre-baked MiniLM) → ECR →
ECS Fargate (desired = 1) behind an ALB; EventBridge calls
`/internal/growth-refresh-all` daily with a shared-secret header; secrets
injected as task environment variables.

## 10. Known limitations

- **ALB listener is HTTP, not HTTPS.** The student AWS account has no ACM
  certificate available, so the deployed API is reachable only over plain
  HTTP. This also means the daily Growth Plaza refresh could not use the
  EventBridge → API-destination design from ADR-0002 (API destinations
  require HTTPS); it runs as an in-process scheduled task inside the
  container instead, with `/internal/growth-refresh-all` kept as a manual
  fallback trigger (see `docs/DEPLOYMENT.md`). iOS requires an explicit App
  Transport Security exception to allow the HTTP connection for this reason.
- **Live LinkedIn tenure is null.** LinkedIn's OIDC scope exposes only name,
  picture and a stable subject id — no employment or tenure data — so the
  Trust Score's LinkedIn component renormalises its weight across the
  remaining available components rather than guessing or defaulting tenure
  to zero (see `trust_service.py`).
- **Messaging is 10-second client polling, not push.** `GET
  /conversations/{id}/messages?after=` is polled from the Flutter client;
  sufficient at demo scale and avoids standing up WebSocket/SSE
  infrastructure in a three-week window, but is not how a production chat
  feature would be built.
- **The matching engine's Gaussian Process Regressor is fit on a small,
  fixed, hand-labelled example set** (see ADR-0001 and
  `services/matching/scoring.py`), not on real user interaction data —
  there isn't any yet. It encodes the product's intended ranking policy
  (e.g. skill-overlap and role-complementarity should score higher) rather
  than a model learned from observed match outcomes. This is disclosed
  rather than presented as a trained recommender.
- **Backend automated testing is unit + integration, not full end-to-end.**
  The 30 API integration tests (§8) exercise real routes against a real
  database, but routes that call out to S3, live GitHub, or Bedrock are
  covered at the service-function level (existing unit tests) rather than
  through the integration layer, to keep the suite offline-deterministic
  and CI-runnable without AWS credentials. Full third-party-inclusive
  end-to-end coverage lives in `integration_test/e2e_test.dart` instead,
  run manually against a live local backend.
- **Adaptive layout is a single breakpoint, not three.** `HomeShell` switches
  between a bottom nav and a side rail at 700px; it does not add a distinct
  desktop layout (e.g. a secondary detail panel) above 1100px. The side
  rail scales adequately up to full desktop width, and a second breakpoint
  was judged not worth the added complexity in the time available.

## 11. Security review (2026-07-20)

A targeted security review of the backend (auth/authorization, input
handling/injection) and frontend (token handling, OAuth/OIDC flows, platform
config) found and fixed two concrete, high-confidence vulnerabilities, plus
one medium-severity platform hardening gap:

- **Account takeover via `POST /auth/github/connect` (fixed).** This
  endpoint minted a valid access token for *any* `github_login` supplied,
  including one belonging to an existing, fully-onboarded account — with no
  proof the caller actually controls that GitHub account. Since GitHub
  logins are public and shown throughout the app (project owners, matches,
  reviewers), this allowed full account takeover of any user by anyone who
  knew their username. Fixed by rejecting the request (409) when the target
  account has already completed onboarding, forcing re-authentication
  through real GitHub OAuth instead; accounts still mid-onboarding (nothing
  private to protect yet) remain reachable so a legitimate "resume
  onboarding after reinstall" flow keeps working. Regression-tested in
  `tests/test_integration_auth_security.py`.
- **IDOR on project screenshots (fixed).** `POST
  /projects/{id}/screenshots` accepted an arbitrary S3 object key from the
  client with no check that the key belonged to that project. Since
  screenshot keys are visible in the public `GET /projects` response, a user
  could attach another user's screenshot key to their own (legitimately
  owned) project, then remove it — triggering a real S3 `delete_object` call
  against the *victim's* object. Fixed by validating the key's
  `screenshots/{project_id}/` prefix before accepting it, mirroring the
  pattern `me.py`'s avatar endpoint already used correctly. Regression-tested
  alongside the fix above.
- **iOS ATS disabled app-wide (fixed).** `Info.plist` set
  `NSAllowsArbitraryLoads=true`, disabling transport security for every host
  the app talks to, to work around the one known HTTP-only host (the demo
  ALB — see §10). Scoped down to an `NSExceptionDomains` entry for just that
  hostname; ATS remains enforced for all other connections (GitHub, S3,
  LinkedIn).
- **Action item, not a code fix:** the JWT signing secret and `ENVIRONMENT`
  flag both have safe-for-local-dev-but-unsafe-if-deployed-as-is defaults
  (`JWT_SECRET=change-me`, `ENVIRONMENT=local`, which also leaves the
  `/auth/dev-login` bypass reachable). The code already guards
  `dev-login` behind `environment == "local"`; what could not be verified
  from a code review alone is whether the *deployed* ECS task definition
  actually overrides both with production-appropriate values, or whether it
  inherited the repo's local-dev defaults. Verify this directly against the
  ECS task definition before the demo — it's a two-minute AWS console check.
