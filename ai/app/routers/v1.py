"""Authenticated ``/v1`` API surface.

Every route mounted here requires a valid Firebase ID token and is
rate-limited per spec rule #6. Sprint 4 replaces the placeholder
``/v1/whoami`` with ``/v1/vision/tag``; Sprint 7 adds
``/v1/agent/reply``.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.auth import AuthenticatedUser, require_auth
from app.config import settings

router = APIRouter(prefix="/v1", tags=["v1"], dependencies=[Depends(require_auth)])

# Per-module limiter so tests can swap it out by overriding
# ``app.state.limiter``. All AI routes must use ``@limiter.limit`` —
# spec rule #6.
limiter = Limiter(key_func=get_remote_address)


class WhoAmIResponse(BaseModel):
    uid: str
    email: str | None
    email_verified: bool


@router.get("/whoami", response_model=WhoAmIResponse)
@limiter.limit(settings.default_rate_limit)
def whoami(
    request: Request,  # required by SlowAPI to derive the rate-limit key
    user: AuthenticatedUser = Depends(require_auth),
) -> WhoAmIResponse:
    """Round-trip the caller's verified identity — useful as a smoke test."""
    return WhoAmIResponse(
        uid=user.uid,
        email=user.email,
        email_verified=user.email_verified,
    )
