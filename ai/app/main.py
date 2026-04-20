"""Vanij AI backend — FastAPI on Cloud Run.

Sprint 3: Firebase Auth bearer-token middleware + structured health
probes + rate-limited ``/v1`` router. Sprint 4 will add the vision
tagger (model loaded once at startup). Sprint 7 will add the LLM CRM
agent (read-only Firestore access).
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.auth import init_firebase_admin
from app.config import settings
from app.routers import agent as agent_router
from app.routers import health as health_router
from app.routers import v1 as v1_router
from app.routers import vision as vision_router
from app.vision.tagger import load_tagger

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s - %(message)s",
)
log = logging.getLogger("vanij")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Boot-time setup. Per spec, heavy work happens once here — not
    per request. firebase-admin + the vision model both load once and
    stay warm across all requests served by this uvicorn worker."""
    if not settings.auth_disabled:
        init_firebase_admin()
    else:
        log.warning("AUTH_DISABLED=true — skipping firebase-admin init")
    app.state.vision_tagger = load_tagger()
    yield


app = FastAPI(
    title="Vanij AI",
    description="Vision tagger + LLM CRM agent.",
    version=settings.app_version,
    lifespan=lifespan,
)

# Reuse the same limiter instance across routers so rate counters are
# shared. SlowAPI attaches its state via ``app.state.limiter``.
app.state.limiter = v1_router.limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS: never use allow_origins=["*"]. Explicit allow-list from settings.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type"],
)

app.include_router(health_router.router)
app.include_router(v1_router.router)
app.include_router(vision_router.router)
app.include_router(agent_router.router)
