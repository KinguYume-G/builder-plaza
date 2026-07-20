from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import auth, growth, health, intent, me, projects, users

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
