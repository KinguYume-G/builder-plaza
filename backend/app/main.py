from fastapi import FastAPI

from app.core.config import settings

app = FastAPI(title="Builder Plaza API", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "environment": settings.environment}
