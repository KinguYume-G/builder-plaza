# Deployment (ADR-0002)

## Live endpoint

    http://builder-plaza-alb-270417897.ap-southeast-1.elb.amazonaws.com

Health: `GET /health` → `{"status":"ok"}`. Point any client at it with
`flutter run --dart-define=API_BASE_URL=<url>`.

## Architecture

- **Image**: `backend/Dockerfile` — python:3.12-slim, CPU-only torch, the
  MiniLM encoder pre-baked at build time (no cold-start model download).
  ~540MB. Built `--platform linux/amd64` for Fargate.
- **Registry**: ECR `150432925757.dkr.ecr.ap-southeast-1.amazonaws.com/builder-plaza-backend`.
- **Compute**: ECS Fargate — cluster `builder-plaza`, service `backend`,
  desired = 1, 1 vCPU / 2GB, public subnets of the default VPC.
- **Ingress**: ALB `builder-plaza-alb` (HTTP :80) → target group
  `builder-plaza-tg` (ip targets :8000, health check `/health`).
- **Security groups**: `bp-alb-sg` (80 from anywhere) → `bp-svc-sg`
  (8000 from the ALB SG only).
- **Data**: existing RDS Postgres (+pgvector), S3 uploads bucket, Bedrock
  Haiku — all reached with the same env config as local.
- **Secrets**: injected as task-definition environment variables from the
  gitignored `.env`. (Secrets Manager would be the production-grade step;
  env vars keep the student account simple.)
- **Logs**: CloudWatch `/ecs/builder-plaza`.

## Scheduled growth refresh — deviation from ADR-0002

EventBridge API destinations require an **HTTPS** endpoint; the demo ALB is
HTTP-only (no custom domain / ACM certificate on this account). Instead, the
API runs an in-process daily task (see `app/main.py`) executing the same
`refresh_all_active` path, enabled only when `INTERNAL_TASK_TOKEN` is set.
`POST /internal/growth-refresh-all` (header `x-internal-token`) remains for
manual or external triggering, and is the EventBridge hook if a cert is
added later.

## Redeploy

```bash
cd backend
docker build --platform linux/amd64 -t builder-plaza-backend .
aws ecr get-login-password --profile builderplaza --region ap-southeast-1 \
  | docker login --username AWS --password-stdin 150432925757.dkr.ecr.ap-southeast-1.amazonaws.com
docker tag builder-plaza-backend:latest 150432925757.dkr.ecr.ap-southeast-1.amazonaws.com/builder-plaza-backend:latest
docker push 150432925757.dkr.ecr.ap-southeast-1.amazonaws.com/builder-plaza-backend:latest
aws ecs update-service --profile builderplaza --region ap-southeast-1 \
  --cluster builder-plaza --service backend --force-new-deployment
```

Seed/reset demo data (runs against RDS from your machine):

```bash
cd backend && .venv/bin/python seed.py
```

## Demo dashboard (Grafana)

A second Fargate service renders the live database view used in the recorded
demo — see `docs/demo-dashboard/`. It is a separate ECS service behind the same
ALB on **port 8080**, with the datasource and dashboard baked into its image and
the database credentials injected as task-definition environment variables.

```
http://builder-plaza-alb-270417897.ap-southeast-1.elb.amazonaws.com:8080
```

Redeploy after editing the dashboard JSON:

```bash
cd docs/demo-dashboard
docker build --platform linux/amd64 -t bp-grafana .
docker tag bp-grafana:latest 150432925757.dkr.ecr.ap-southeast-1.amazonaws.com/builder-plaza-grafana:latest
docker push 150432925757.dkr.ecr.ap-southeast-1.amazonaws.com/builder-plaza-grafana:latest
aws ecs update-service --profile builderplaza --region ap-southeast-1 \
  --cluster builder-plaza --service grafana --force-new-deployment
```

It is **anonymous and public** — anyone with the URL sees real row contents
(pitches, message bodies). Acceptable for the assessment window; delete the 8080
listener afterwards.

## Sign-in on the deployed backend

`ALLOW_DEV_LOGIN=true` is set on `builder-plaza-backend:5`. It is required, not
convenience: `/auth/github/connect` returns 409 once an account has completed
onboarding, and the real OAuth callback redirects to a *web* frontend, so the
Android build cannot finish a real sign-in. Without the flag nobody can log in
against this deployment at all. **Remove it once the assessment is done** —
register a task-definition revision without the variable and update the service.

## Cost teardown (after the demo)

```bash
# Backend
aws ecs update-service --cluster builder-plaza --service backend --desired-count 0
aws ecs delete-service --cluster builder-plaza --service backend --force

# Demo dashboard — a second always-on Fargate task, easy to forget
aws ecs update-service --cluster builder-plaza --service grafana --desired-count 0
aws ecs delete-service --cluster builder-plaza --service grafana --force
aws elbv2 delete-listener --listener-arn <the :8080 listener>
aws elbv2 delete-target-group --target-group-arn <builder-plaza-grafana-tg>

aws elbv2 delete-load-balancer --load-balancer-arn <alb-arn>   # ALB is the main cost (~$0.75/day)
aws elbv2 delete-target-group --target-group-arn <tg-arn>
aws ecs delete-cluster --cluster builder-plaza
```
