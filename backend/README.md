# Builder Plaza — Backend

FastAPI backend for Builder Plaza. See [`../PRD.md`](../PRD.md) for product scope and [`../docs/adr/`](../docs/adr/) for the architecture decisions — mainly [ADR-0002](../docs/adr/0002-backend-python-fastapi-aws.md) (Python/FastAPI on AWS, ECS Fargate) and [ADR-0001](../docs/adr/0001-matching-engine-sbert-gpr.md) (matching engine).

**For current status, read [`../docs/REPORT.md`](../docs/REPORT.md) and [`../docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md), not the "What was verified" log at the bottom of this file** — that log is a historical record from when this really was just a scaffold (2026-07-14/15) and was, for a while, incorrectly copied into other docs as if it were still current. It isn't; see below.

## Current state (corrected 2026-07-20)

This is a working feature build, not a scaffold. All F1–F10 modules from the PRD are implemented (F9 is intentionally Mocked — see PRD's Live/Mocked tiering): Dual-Source Trust Gateway (GitHub OAuth + LinkedIn OIDC live/simulated), Profile & Completeness, Project Card CRUD + S3 screenshots, Growth Plaza (GitHub polling + Bedrock summarisation), Discovery/Matching (SBERT + pgvector + GaussianProcessRegressor), Trust Score, Controlled DM, Request Market, and Verified Activity Timeline. It's deployed on AWS ECS Fargate behind an ALB (see `docs/DEPLOYMENT.md` for the live URL). The database schema (11 tables) is at Alembic revision `0003` (initial schema + trust-gateway JSONB fields + cached GitHub events). Test suite: 171 pytest cases — 141 pure unit tests plus 30 API integration tests (`tests/test_integration_*.py`, added 2026-07-20) that exercise real routes against a real Postgres+pgvector database via `TestClient` + transactional fixtures (see `tests/conftest.py` and `docker-compose.yml` for the local throwaway test DB; CI runs the same suite against a Postgres service container).

## Stack

- **Python 3.12**, FastAPI, Uvicorn
- **PostgreSQL + pgvector** for structured data and skill embeddings (RDS in production)
- **Local dev:** a virtualenv (`.venv`)
- **Production:** a Docker container on **AWS ECS Fargate** behind an ALB, image in ECR (ADR-0002). There is no Docker-Compose fallback — cloud is the only deploy target — but you should still build the image locally to verify it before pushing to ECR.

## Project layout

```
backend/
  app/
    core/config.py      # pydantic-settings — reads env vars, see table below
    core/security.py    # JWT create/decode, get_current_user dependency
    db/
      base.py            # SQLAlchemy engine, session, declarative Base
      models.py           # all 11 ORM models, mirrors PRD.md 6.1 ERD
      session.py          # get_db() -- FastAPI dependency, yields a Session per request
    routers/             # auth, me, projects, intent, growth, users, matches,
                          # requests, role_postings, mocked, health -- one file per F-module
    schemas/              # Pydantic request/response contracts, one file per domain
    services/             # business logic: auth, github_oauth/provider, linkedin_oauth,
                          # identity_provider, growth_service, bedrock_service, trust_service,
                          # collab_service, completeness, s3_service, matching/ (engine,
                          # embeddings, scoring, credibility, skill_text)
    main.py              # FastAPI app, router registration, daily growth-refresh task
  alembic/
    env.py               # wired to app.core.config.settings, not alembic.ini
    versions/            # 0001_initial_schema, 0002_trust_gateway, 0003_github_events
  alembic.ini
  tests/
    conftest.py                 # fixtures for the integration layer below (real DB + TestClient)
    test_integration_*.py       # 5 files, 30 cases: auth, me, projects, requests, role_postings
    test_*.py                   # 13 files of pure unit tests (schemas, services, scoring, etc.)
  docker-compose.yml     # throwaway local Postgres+pgvector for the integration test layer only
  requirements.txt       # runtime deps
  requirements-dev.txt   # runtime deps + pytest
  Dockerfile              # python:3.12-slim, non-root user, mirrors the ECS Fargate target
  .dockerignore
  .gitignore              # .venv/, __pycache__/, .pytest_cache/, etc.
  pytest.ini              # pythonpath = . , so `from app...` resolves under pytest
```

## Getting started (local dev)

Run everything from the `backend/` directory.

**1. Create the virtualenv** (Python 3.12; if you have multiple Pythons installed, point at the 3.12 one explicitly):

```
python -m venv .venv
```

**2. Activate it**

- PowerShell: `.venv\Scripts\Activate.ps1`
- Git Bash / WSL: `source .venv/Scripts/activate`

**3. Install dependencies**

```
python -m pip install -r requirements-dev.txt
```

**4. Set up environment variables**

Copy `../.env.example` to `../.env` (repo root — one `.env` covers the whole project) and fill in real values as you need them. Every setting in `app/core/config.py` has a safe local default, so the app runs with no `.env` at all until you actually need GitHub OAuth, a real database, or AWS access.

**5. Run the dev server**

```
uvicorn app.main:app --reload --port 8000
```

Visit `http://127.0.0.1:8000/health` and `http://127.0.0.1:8000/docs` (Swagger UI, free from FastAPI).

**6. Run tests**

```
pytest -v
```

The `tests/test_integration_*.py` files need a real Postgres+pgvector database (never the shared dev RDS — see below). Start the throwaway local one and point `DATABASE_URL` at it:

```
docker compose up -d
DATABASE_URL="postgresql+psycopg://postgres:postgres@localhost:55432/builder_plaza_test" pytest -v
```

Without `DATABASE_URL` set this way, the fixtures fall back to the same default (`docker-compose.yml`'s port), so `pytest -v` alone works too as long as that container is running. The other 13 test files are pure unit tests and don't need a database at all. CI runs the whole suite against a Postgres service container (`.github/workflows/ci.yml`), so this is exercised on every push, not just locally.

## Environment variables

Defined in `app/core/config.py`, sourced from `../.env` (or a local `backend/.env` override if you create one). All have local defaults except where noted.

| Variable | Purpose | Notes |
|---|---|---|
| `ENVIRONMENT` | `local` / `production` flag | defaults to `local` |
| `DATABASE_URL` | Postgres connection string | defaults to a local Postgres on `localhost:5432` |
| `JWT_SECRET` | signs the GitHub-OAuth-rooted custom JWT | **must** be overridden outside local dev |
| `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` | GitHub OAuth (F1 Trust Gateway) | required for the real `/auth/github/login` redirect flow; `/auth/github/connect` (public-data connect) works without it |
| `LINKEDIN_CLIENT_ID` / `LINKEDIN_CLIENT_SECRET` | LinkedIn OIDC | already in root `.env` |
| `LINKEDIN_MODE` | `simulated` \| `live` — selects the `IdentityProvider` impl | see [ADR-0003](../docs/adr/0003-linkedin-dual-implementation.md) — status is **Go**, `live` is the production path; `simulated` is mandatory for the automated test suite regardless of this flag. Note: `/auth/linkedin/profiles` and `/auth/linkedin/bind` are simulated-mode-only by design (409 if `live`) — the real OIDC flow uses `/auth/linkedin/login` + `/auth/linkedin/callback` instead |
| `AWS_REGION` | AWS SDK (boto3) region | for S3 + Bedrock calls |
| `S3_BUCKET_NAME` | avatar / project-screenshot uploads | used by `/me/avatar*` and `/projects/{id}/screenshots*` |
| `BEDROCK_MODEL_ID` | Growth Plaza summarisation model | defaults to Claude Haiku |

## Database (AWS RDS PostgreSQL)

There's one shared instance for the team — no local Postgres, no Docker Postgres. Whoever hasn't set it up yet:

**1. Create the RDS instance** (AWS Console → RDS → Create database → Standard create):

| Setting | Value | Why |
|---|---|---|
| Engine | PostgreSQL 16.x | pgvector needs 15.2+; 16 has the most stable support |
| Template | Free tier (or Dev/Test if ineligible) | plenty for dev + demo data volume |
| Instance class | `db.t3.micro` / `db.t4g.micro` | free-tier eligible |
| Storage | 20 GiB gp3, autoscaling off | avoids surprise cost, not needed at this scale |
| Public access | **Yes** | teammates connect straight from their laptops, not from inside a VPC |
| VPC security group | new, e.g. `builder-plaza-db-sg`, inbound rule `0.0.0.0/0` on port 5432 | per-teammate IP allowlisting sounds tighter but everyone's home/mobile IP drifts, turning this into a recurring "why can't I connect" chore for a disposable dev DB with no real user data yet — decided the maintenance wasn't worth it. What actually protects the DB is the master password, so make it a real one |
| Authentication | Password | simplest for a 3-person team, no IAM users to manage |
| Initial database name | `builder_plaza` | must be set here — RDS won't create it later on its own |

Region: use whatever your AWS CLI default region already is (`ap-southeast-1` as of this scaffold) so it's next to everything else in ADR-0002.

**2. Build the connection string** from the instance's Connectivity tab (Endpoint + Port):

```
DATABASE_URL=postgresql+psycopg://<master_username>:<master_password>@<endpoint>:5432/builder_plaza
```

Put it in the root `.env` (gitignored). Share the endpoint/username/password with teammates over a private channel — never commit it, never paste it into a public/logged chat.

For this project's actual instance: master username is `builderplaza05` (not AWS's default `postgres` — RDS lets you pick your own at creation time), endpoint is `builder-plaza-dev.cx8as0yaao9f.ap-southeast-1.rds.amazonaws.com`. Get the password from Ti Huai directly, not from this file.

**3. Create the tables** — once `DATABASE_URL` is set and your IP is allowed through the security group:

```
cd backend
alembic upgrade head
```

This runs `alembic/versions/0001_initial_schema.py`: enables the `vector` extension, creates all 9 enum types, and creates all 11 tables in one shot. Every teammate runs the same command against the same `DATABASE_URL` to get an identical schema — that's the reason this is a versioned Alembic migration and not a one-off SQL script someone runs by hand once.

Verify it worked:

```
psql "$DATABASE_URL" -c "\dt"
```

(or any GUI client — TablePlus, DBeaver, pgAdmin — if nobody has `psql` installed locally)

**Schema gaps to resolve as a team:** `project_cards.stage`, `role_postings.stage`, and `collab_requests.intent_type` are plain strings, not DB enums — the PRD names these fields but never enumerates their actual values anywhere (F3/F7/F8). Pick the value sets before relying on them anywhere, then it's a one-line Alembic migration to convert to a real `ENUM`.

## Local vs. production environment

These are two different mechanisms, not the same thing at different scales:

- **Local dev = virtualenv.** Fast iteration, no container overhead, standard `pip install`.
- **Production = Docker container on ECS Fargate.** The venv never ships anywhere — `Dockerfile` installs straight into the image's system Python. ECS Fargate has no concept of a virtualenv; it runs whatever the container runs.

Before pushing to ECR, build and run the image locally to confirm parity with the venv:

```
docker build -t builder-plaza-backend .
docker run --rm -p 8000:8000 --env-file ../.env builder-plaza-backend
```

(Not yet verified on this machine — Docker Desktop wasn't running when the scaffold was built. Run this yourself once it's up.)

## Known limitations (current, not historical)

- **ALB is HTTP-only** — no ACM certificate on the student AWS account, so there's no HTTPS in front of the deployed API. See `docs/DEPLOYMENT.md`.
- **LinkedIn OIDC exposes no employment/tenure data**, so the Trust Score's LinkedIn component renormalises around the components that are available rather than treating tenure as zero.
- **Messaging is 10-second client polling, not push** (`GET /conversations/{id}/messages?after=`) — simplest thing that works within the project's time budget; no WebSocket/SSE infra.
- **The GaussianProcessRegressor in `services/matching/scoring.py` is fit on a small, fixed, hand-labelled example set**, not on real interaction data (there isn't any yet) — it encodes the product's intended ranking policy, not a learned one.
- **`GET /health/db` has no pytest test** — deliberate: `test_health.py` needs zero setup (no `.env`, no database) so a fresh clone gets a green run immediately. The DB-touching layer is `tests/test_integration_*.py` instead (real Postgres, see above), not a mocked `/health/db`.

## What was verified when this scaffold was built (historical log — see "Current state" above for what's true today)

### 2026-07-14

- `pytest` run from `backend/`: 1 passed.
- `uvicorn` started for real (not just the test client) and `GET /health` / `GET /docs` were curled and returned 200.
- `docker build` was **not** verified — Docker Desktop's daemon wasn't running on the dev machine at the time.

### 2026-07-15

- All 11 models import cleanly and register on `Base.metadata`.
- `alembic upgrade head --sql` (offline mode, no live DB needed) rendered without error — confirms the extension, all 9 enum types, and all 11 `CREATE TABLE` statements, including the `pgvector` column, are valid PostgreSQL DDL.
- The RDS instance (`builder-plaza-dev`, PostgreSQL, `ap-southeast-1`) was provisioned and `alembic upgrade head` was run against it **for real** — succeeded.
- Confirmed independently of Alembic's own bookkeeping: queried `pg_tables` directly and got back all 11 application tables plus `alembic_version`; queried `pg_extension` and confirmed `vector` is installed.
- `pytest` re-run after the DB work: still 1 passed, no regressions.
- Added `app/db/session.py` (`get_db()` FastAPI dependency) and `GET /health/db`; started `uvicorn` for real and curled it against the live RDS instance — got back `{"status": "ok", "users_count": 0}` (0 is correct, no rows seeded yet). Confirms the dependency-injection wiring, not just the raw SQLAlchemy connection.

### 2026-07-20 (full feature build, not a scaffold anymore)

- All F1–F10 modules implemented and code-reviewed against the PRD (F9 intentionally Mocked); deployed to AWS ECS Fargate (see `docs/DEPLOYMENT.md` for the live ALB URL).
- Added `tests/conftest.py` + `tests/test_integration_*.py`: 30 new API integration tests running real `TestClient` requests through real routes against a real Postgres+pgvector database (transactional per-test isolation via SQLAlchemy's `join_transaction_mode="create_savepoint"`, never the shared dev RDS). `docker compose up -d` + `pytest -v` run: **171 passed, 0 failed**.
- Added `docker-compose.yml` (throwaway local test DB) and a Postgres service container to `.github/workflows/ci.yml` so the integration layer runs in CI, not only locally.
- Fixed `services/identity_provider.py`: `LINKEDIN_MODE=live` previously raised an unhandled `NotImplementedError` (500) from `/auth/linkedin/profiles` and `/auth/linkedin/bind` (both simulated-mode-only by design — live OIDC uses separate `/auth/linkedin/login`+`/callback` routes); now returns a clean 409 with an explanatory message instead.
