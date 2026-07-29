# Builder Plaza documentation

This directory contains focused technical, operational, assessment, and
user-facing documentation. Use this index to find the authoritative source for
each topic instead of duplicating details across files.

## Start here

| Document | Purpose |
|---|---|
| [`../README.md`](../README.md) | Repository and product overview |
| [`../PRD.md`](../PRD.md) | Product requirements, feature traceability, architecture, ERD, and test plan |
| [`../CONTEXT.md`](../CONTEXT.md) | Canonical terminology, Live/Simulated boundary, and prohibited claims |
| [`USER_MANUAL.md`](USER_MANUAL.md) | User-facing navigation and workflow guide |
| [`REPORT.md`](REPORT.md) | Technical report working source and implementation evidence |

## Architecture decisions

| ADR | Decision |
|---|---|
| [`adr/0001-matching-engine-sbert-gpr.md`](adr/0001-matching-engine-sbert-gpr.md) | MiniLM/pgvector recall plus Gaussian-process scoring and exploration |
| [`adr/0002-backend-python-fastapi-aws.md`](adr/0002-backend-python-fastapi-aws.md) | Python/FastAPI backend and AWS deployment architecture |
| [`adr/0003-linkedin-dual-implementation.md`](adr/0003-linkedin-dual-implementation.md) | Live LinkedIn OIDC plus a labelled simulated test/demo path |

ADRs record why a decision was made. Current operational details belong in the
deployment and component READMEs.

## Development and operations

| Document | Purpose |
|---|---|
| [`../frontend/README.md`](../frontend/README.md) | Flutter structure, local run, tests, and responsive behaviour |
| [`../backend/README.md`](../backend/README.md) | FastAPI structure, environment, database, migrations, and tests |
| [`DEPLOYMENT.md`](DEPLOYMENT.md) | ECS/RDS/S3/ALB deployment and cost teardown |
| [`linkedin-application-guide.md`](linkedin-application-guide.md) | LinkedIn Developer Portal setup |
| [`test-evidence/README.md`](test-evidence/README.md) | Test-evidence storage conventions |

## Demo and assessment

| Document | Purpose |
|---|---|
| [`DEMO_VIDEO_PLAN.md`](DEMO_VIDEO_PLAN.md) | Final group recording plan and rubric coverage |
| [`DEMO_SCRIPT.md`](DEMO_SCRIPT.md) | Concise one-take walkthrough |
| [`demo-script-wei.md`](demo-script-wei.md) | Builder-segment recording script |

## Documentation rules

1. Treat [`../CONTEXT.md`](../CONTEXT.md) as the terminology and claim boundary.
2. Describe F1-F8/F10 as Live and F9 as Simulated.
3. Use exact test totals only when supported by the latest terminal or CI output.
4. Keep secrets, access tokens, private contact data, and signing material out of
   documentation and screenshots.
5. Update the closest authoritative document rather than copying the same
   operational instructions into several files.

