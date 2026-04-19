"""Vanij AI backend — FastAPI on Cloud Run (Sprint 1 skeleton).

Sprint 3 will add auth middleware + Firestore-verified ID token handling.
Sprint 4 will add the vision tagger (model loaded once at startup).
Sprint 7 will add the LLM CRM agent (read-only Firestore access).
"""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from app.config import settings

# Load the rate limiter once at import time; handlers opt in via decorator.
limiter = Limiter(key_func=get_remote_address)

app = FastAPI(
    title="Vanij AI",
    description="Vision tagger + LLM CRM agent.",
    version="0.1.0",
)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS: never use allow_origins=["*"]. Explicit allow-list from settings.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type"],
)


@app.get("/health")
def health() -> dict[str, object]:
    """Liveness probe consumed by Cloud Run + uptime monitors."""
    return {"ok": True, "service": "vanij-ai", "version": app.version}
