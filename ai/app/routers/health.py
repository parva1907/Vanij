"""Liveness + readiness probes.

``/health`` is a cheap liveness check suitable for Cloud Run's startup
probe. ``/ready`` additionally checks that expensive-to-init resources
(currently only ``firebase-admin``) are ready to serve traffic.
"""

from __future__ import annotations

import time

import firebase_admin
from fastapi import APIRouter
from pydantic import BaseModel

from app.config import settings

router = APIRouter(tags=["health"])

_BOOT_TS = time.monotonic()


class HealthResponse(BaseModel):
    ok: bool
    service: str
    version: str
    environment: str
    uptime_seconds: float


class ReadyResponse(HealthResponse):
    firebase_admin_ready: bool


@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(
        ok=True,
        service="vanij-ai",
        version=settings.app_version,
        environment=settings.environment,
        uptime_seconds=round(time.monotonic() - _BOOT_TS, 3),
    )


@router.get("/ready", response_model=ReadyResponse)
def ready() -> ReadyResponse:
    firebase_ready = bool(firebase_admin._apps)  # type: ignore[attr-defined]
    # When ``AUTH_DISABLED=true`` (local dev / tests) we intentionally skip
    # the firebase-admin init, so treating ``firebase_admin._apps`` as the
    # sole readiness signal would wrongly mark the service unhealthy. In
    # that mode the service is ready once the FastAPI app has booted.
    is_ready = firebase_ready or settings.auth_disabled
    return ReadyResponse(
        ok=is_ready,
        service="vanij-ai",
        version=settings.app_version,
        environment=settings.environment,
        uptime_seconds=round(time.monotonic() - _BOOT_TS, 3),
        firebase_admin_ready=firebase_ready,
    )
