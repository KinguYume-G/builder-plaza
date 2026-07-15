# Builder Plaza — Backend

FastAPI backend for Builder Plaza. See [`../PRD.md`](../PRD.md) for product scope and [`../docs/adr/`](../docs/adr/) for the architecture decisions this scaffold follows — mainly [ADR-0002](../docs/adr/0002-backend-python-fastapi-aws.md) (Python/FastAPI on AWS, ECS Fargate) and [ADR-0001](../docs/adr/0001-matching-engine-sbert-gpr.md) (matching engine, not yet implemented).

## Current state

This is a scaffold, not a feature build. It boots, serves `GET /health`, and has one passing test. The full database schema (11 tables, from the PRD's ERD) exists as SQLAlchemy models and an Alembic migration, but no route uses the database yet. None of the F1–F10 modules in the PRD exist yet — auth and every route are still to be built.

## Stack

- **Python 3.12**, FastAPI, Uvicorn
- **PostgreSQL + pgvector** for structured data and skill embeddings (RDS in production)
- **Local dev:** a virtualenv (`.venv`)
- **Production:** a Docker container on **AWS ECS Fargate** behind an ALB, image in ECR (ADR-0002). There is no Docker-Compose fallback — cloud is the only deploy target — but you should still build the image locally to verify it before pushing to ECR.

## Project layout

```
backend/
  app/
    core/config.py     # pydantic-settings — reads env vars, see table below
    db/
      base.py            # SQLAlchemy engine, session, declarative Base
      models.py           # all 11 ORM models, mirrors PRD.md 6.1 ERD
    main.py             # FastAPI app, GET /health
  alembic/
    env.py               # wired to app.core.config.settings, not alembic.ini
    versions/0001_initial_schema.py  # creates the pgvector extension + all tables
  alembic.ini
  tests/
    test_health.py      # pytest, exercises /health via FastAPI's TestClient
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

## Environment variables

Defined in `app/core/config.py`, sourced from `../.env` (or a local `backend/.env` override if you create one). All have local defaults except where noted.

| Variable | Purpose | Notes |
|---|---|---|
| `ENVIRONMENT` | `local` / `production` flag | defaults to `local` |
| `DATABASE_URL` | Postgres connection string | defaults to a local Postgres on `localhost:5432` |
| `JWT_SECRET` | signs the GitHub-OAuth-rooted custom JWT | **must** be overridden outside local dev |
| `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` | GitHub OAuth (F1 Trust Gateway) | empty until F1 is built |
| `LINKEDIN_CLIENT_ID` / `LINKEDIN_CLIENT_SECRET` | LinkedIn OIDC | already in root `.env` |
| `LINKEDIN_MODE` | `simulated` \| `live` — selects the `IdentityProvider` impl | see [ADR-0003](../docs/adr/0003-linkedin-dual-implementation.md); `simulated` is mandatory for the automated test suite regardless of this flag |
| `AWS_REGION` | AWS SDK (boto3) region | for S3 + Bedrock calls |
| `S3_BUCKET_NAME` | avatar / project-screenshot uploads | empty until F2/F3 wire up pre-signed URLs |
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

## Deliberately deferred

- **`sentence-transformers` / `scikit-learn`** (the SBERT + Gaussian-process matching engine from ADR-0001) are left out of `requirements.txt`. They pull in `torch` and meaningfully slow down every install; add them when F5 (matching engine) actually starts.
- **No route uses the database yet** — the schema is live on RDS (see Database section above), but no FastAPI endpoint opens a session or queries anything yet.
- **No auth is wired up yet** — `pyjwt` is installed, `JWT_SECRET` is read, but there's no `IdentityProvider`, no GitHub OAuth flow, no JWT issuance.

## What was verified when this scaffold was built

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
