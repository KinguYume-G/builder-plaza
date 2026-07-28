import asyncio
import contextlib
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings

from app.routers import (
    auth,
    demo,
    growth,
    health,
    intent,
    matches,
    me,
    mocked,
    projects,
    requests,
    role_postings,
    users,
)

app = FastAPI(title="Builder Plaza API", version="0.1.0")

# Flutter web runs on a different origin and authenticates with Bearer tokens
# (not cookies), so a wildcard origin with credentials disabled is enough.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=False,
)

app.include_router(health.router)
app.include_router(auth.router)
app.include_router(me.router)
app.include_router(projects.router)
app.include_router(intent.router)
app.include_router(growth.router)
app.include_router(users.router)
app.include_router(matches.router)
app.include_router(requests.router)
app.include_router(role_postings.router)
app.include_router(mocked.router)
app.include_router(demo.router)


# --- F4 scheduled growth refresh ------------------------------------------
# ADR-0002 planned EventBridge -> API destination, but API destinations
# require an HTTPS endpoint and the demo ALB has no domain/cert. Deviation
# (recorded in docs/DEPLOYMENT.md): an in-process daily task runs the same
# refresh_all_active path. The /internal/growth-refresh-all endpoint remains
# for manual/external triggering. Enabled only when INTERNAL_TASK_TOKEN is
# set, so local dev servers don't poll GitHub in the background.

_DAILY_SECONDS = 24 * 60 * 60
logger = logging.getLogger("uvicorn.error")


async def _daily_growth_loop() -> None:
    from app.db.session import SessionLocal
    from app.services import growth_service

    while True:
        await asyncio.sleep(_DAILY_SECONDS)
        try:
            db = SessionLocal()
            try:
                written = await asyncio.to_thread(growth_service.refresh_all_active, db)
                logger.info("scheduled growth refresh: %s post(s) written", written)
            finally:
                db.close()
        except Exception:
            logger.exception("scheduled growth refresh failed; retrying tomorrow")


@app.on_event("startup")
async def _start_scheduler() -> None:
    if settings.internal_task_token:
        app.state.growth_task = asyncio.create_task(_daily_growth_loop())


@app.on_event("shutdown")
async def _stop_scheduler() -> None:
    task = getattr(app.state, "growth_task", None)
    if task is not None:
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task
