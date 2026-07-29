# Builder Plaza

<p align="center">
  <img src="./images/Builder_Plaza_Logo.png" alt="Builder Plaza logo" width="180">
</p>

<p align="center">
  A cross-platform collaboration plaza built around verified work, current intent,
  explainable matching, and controlled contact.
</p>

Builder Plaza helps builders, collaborators, and founders answer a practical
question:

> Is this person credible, open to collaborate now, and safe to contact in this
> specific context?

The Flutter client brings together verified GitHub activity, an authorised
LinkedIn identity, Project Cards, collaboration intent, explainable matches,
Trust Scores, structured requests, and post-acceptance messaging. The FastAPI
backend provides the REST API, PostgreSQL persistence, matching and trust
services, third-party integrations, and media-storage workflow.

## What the application supports

- **Dual-Source Trust Gateway** — GitHub OAuth plus LinkedIn OIDC, with an
  explicitly labelled simulated LinkedIn path for repeatable demos and tests.
- **One account, three perspectives** — switch between Builder, Collaborator,
  and Founder without duplicating identity or project data.
- **Project Cards and Intent Badges** — create, update, discover, and archive
  projects while showing what each user is open to now.
- **Growth Plaza** — turn recent GitHub repository activity into readable
  product-progress updates, using Amazon Bedrock with a deterministic fallback.
- **Explainable matching** — MiniLM embeddings, pgvector recall,
  `GaussianProcessRegressor` scoring, and an epsilon-greedy exploration slot;
  every result includes a human-readable Match Reason.
- **Trust and evidence** — GitHub continuity, repository roles, LinkedIn tenure,
  peer-review signals, and a clearly simulated payment-identity component.
- **Controlled collaboration** — structured requests must be accepted before a
  conversation opens; raw contact details are not required.
- **Request Market** — maintainer and team-role postings with type-specific
  validation, filtering, and project-ownership checks.
- **Responsive Flutter UI** — bottom navigation on narrow screens and a side
  rail on wide layouts from the same shared navigation shell.
- **Automated quality gates** — backend unit/integration tests, Flutter
  model/widget/responsive tests, Android end-to-end flows, Monkey exploration,
  static analysis, and GitHub Actions release automation.

## Live and simulated scope

Builder Plaza distinguishes implemented product functionality from concept
demonstrations:

| Tier | Scope |
|---|---|
| **Live** | F1-F8 and F10: identity, profiles, projects, intent, Growth Plaza, matching, Trust Score, controlled requests/messages, Request Market, and verified activity/evidence |
| **Simulated** | F9: Sandbox replay, AI Shortlist, Agent Access, and Proof-of-Work interaction panels |
| **Simulated component** | The payment-identity contribution inside Trust Score |

Simulated screens are visibly labelled in the UI. They demonstrate intended
interaction and business boundaries; they do not execute untrusted code,
autonomous recruitment, external agents, or a real cryptographic challenge.

## Architecture

```text
Flutter (Provider, GoRouter, Dio)
            |
          HTTPS/REST
            |
FastAPI (JWT, Pydantic, SQLAlchemy, services)
      |              |                 |
PostgreSQL       Amazon S3        External services
 + pgvector      private media     GitHub / LinkedIn / Bedrock
```

- **Client:** Flutter/Dart, Material 3, Provider/ChangeNotifier, GoRouter, Dio,
  `shared_preferences`, `image_picker`, and `fl_chart`.
- **API:** Python 3.12, FastAPI, Uvicorn, Pydantic, SQLAlchemy, and Alembic.
- **Data:** PostgreSQL with pgvector; private image objects in Amazon S3.
- **Matching:** `all-MiniLM-L6-v2`, cosine recall, Gaussian-process scoring, and
  controlled exploration.
- **Cloud:** Docker, Amazon ECR, ECS Fargate, Application Load Balancer, RDS,
  S3, and Bedrock.
- **Delivery:** GitHub Actions, Android emulator E2E, Monkey crawl, and release
  APK generation.

Architecture decisions are recorded in [`docs/adr`](docs/adr/), and the full
product contract is in [`PRD.md`](PRD.md).

## Repository layout

```text
builder-plaza/
├── frontend/          # Flutter application, widget tests, and Android E2E flow
├── backend/           # FastAPI API, services, Alembic migrations, and pytest
├── docs/              # ADRs, deployment, demo, report, and user documentation
├── images/            # Repository and product artwork
├── .github/           # CI/CD and Android test workflows
├── .env.example       # Shared environment-variable template
├── CONTEXT.md         # Canonical project terminology and scope boundaries
└── PRD.md             # Product requirements and traceability
```

## Quick start

### Prerequisites

- Flutter compatible with Dart `^3.11.5`
- Python 3.12
- Docker Desktop (for the local PostgreSQL/pgvector test database)
- Android Studio/emulator or a physical Android device

### 1. Configure the environment

Copy [`.env.example`](.env.example) to `.env` at the repository root. Local
development can use `LINKEDIN_MODE=simulated`; Live OAuth and AWS features
require their corresponding credentials. Never commit `.env`.

### 2. Start the backend

```bash
cd backend
python -m venv .venv
# PowerShell: .venv\Scripts\Activate.ps1
# Bash/WSL:   source .venv/bin/activate
python -m pip install -r requirements-dev.txt
docker compose up -d
alembic upgrade head
uvicorn app.main:app --reload --port 8000
```

Verify:

- Health: `http://127.0.0.1:8000/health`
- OpenAPI/Swagger: `http://127.0.0.1:8000/docs`

See [`backend/README.md`](backend/README.md) for database and environment
details.

### 3. Run Flutter

```bash
cd frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

For an Android emulator, use `http://10.0.2.2:8000` instead of
`127.0.0.1`. See [`frontend/README.md`](frontend/README.md) for platform and
test commands.

## Testing

```bash
# Backend: start its throwaway Postgres/pgvector container first
cd backend
docker compose up -d
python -m pytest -q

# Flutter model, widget, and responsive tests
cd ../frontend
flutter analyze
flutter test
```

The Android CI tier migrates and seeds an isolated database, starts Uvicorn,
runs `integration_test/e2e_test.dart` on an emulator, then performs a fixed-seed
1,500-event UI/Application Exerciser Monkey crawl. Exact test totals should be
taken from the latest CI run because parameterised pytest cases may change as
coverage grows.

## Current engineering safeguards

The latest hardening pass adds:

- non-default JWT enforcement outside local/test environments;
- constant-time comparison for the internal task token;
- short-lived, validated OAuth state and controlled provider failure handling;
- conditional request-state transitions and transactional conversation creation;
- a database-level unique guard against duplicate pending requests;
- project-ownership checks and a 5 MB post-upload S3 object-size limit;
- SQL filtering before pagination and type-specific Role Posting invariants;
- global Flutter session clearing after an unauthorised API response;
- database indexes for frequently queried foreign-key paths.

Database migrations currently run through
`0004_indexes_and_constraints`.

## Documentation

Start with [`docs/README.md`](docs/README.md) for the documentation map:

- [`PRD.md`](PRD.md) — requirements, roles, feature traceability, and ERD
- [`CONTEXT.md`](CONTEXT.md) — canonical terminology and claim boundaries
- [`docs/USER_MANUAL.md`](docs/USER_MANUAL.md) — user-facing workflows
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) — AWS deployment and operations
- [`docs/REPORT.md`](docs/REPORT.md) — technical report working source
- [`docs/DEMO_VIDEO_PLAN.md`](docs/DEMO_VIDEO_PLAN.md) — assessed demo plan

## Team

- Choong Ti Huai
- Liu Wei
- Gao Xing

Builder Plaza was developed for the CT124-3-2 Mobile App Engineering group
assignment at Asia Pacific University.
