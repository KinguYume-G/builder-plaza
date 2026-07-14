# Builder Plaza — Backend

FastAPI backend for Builder Plaza. See [`../PRD.md`](../PRD.md) for product scope and [`../docs/adr/`](../docs/adr/) for the architecture decisions this scaffold follows — mainly [ADR-0002](../docs/adr/0002-backend-python-fastapi-aws.md) (Python/FastAPI on AWS, ECS Fargate) and [ADR-0001](../docs/adr/0001-matching-engine-sbert-gpr.md) (matching engine, not yet implemented).

## Current state

This is a scaffold, not a feature build. It boots, serves `GET /health`, and has one passing test. None of the F1–F10 modules in the PRD exist yet — auth, DB models, and every route are still to be built.

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
    main.py             # FastAPI app, GET /health
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
- **No database connection is wired up yet** — `DATABASE_URL` is read into settings but nothing uses it. SQLAlchemy + the `pgvector` extension are installed and ready.
- **No auth is wired up yet** — `pyjwt` is installed, `JWT_SECRET` is read, but there's no `IdentityProvider`, no GitHub OAuth flow, no JWT issuance.

## What was verified when this scaffold was built (2026-07-14)

- `pytest` run from `backend/`: 1 passed.
- `uvicorn` started for real (not just the test client) and `GET /health` / `GET /docs` were curled and returned 200.
- `docker build` was **not** verified — Docker Desktop's daemon wasn't running on the dev machine at the time.
