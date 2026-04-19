"""Firebase Auth middleware.

Every request to a protected route must carry a valid Firebase ID token
in the ``Authorization: Bearer <jwt>`` header. The token is verified via
``firebase-admin``; on success the verified ``uid`` is attached to
``request.state.uid`` and exposed through the
:func:`require_auth` FastAPI dependency.

Security notes:
  * We never log the raw token — only the ``uid`` after verification.
  * ``auth_disabled=true`` is honoured only outside production (guarded
    by :attr:`~app.config.Settings.is_production`).
  * ``firebase-admin`` is initialised lazily so unit tests can opt-out
    without needing a service account credential.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

import firebase_admin
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth as fb_auth

from app.config import settings

log = logging.getLogger("vanij.auth")

_bearer = HTTPBearer(auto_error=False, description="Firebase ID token")


@dataclass(frozen=True, slots=True)
class AuthenticatedUser:
    """Subset of the Firebase token claims the app actually needs."""

    uid: str
    email: str | None
    email_verified: bool


def init_firebase_admin() -> None:
    """Initialise the default ``firebase-admin`` app (idempotent).

    In production, the Cloud Run service account is picked up
    automatically by ``firebase_admin.initialize_app()`` via Application
    Default Credentials. In dev, point ``GOOGLE_APPLICATION_CREDENTIALS``
    at a service-account JSON and set ``FIREBASE_PROJECT_ID`` in
    ``ai/.env``. Never commit either file.
    """
    if firebase_admin._apps:  # type: ignore[attr-defined]
        return
    try:
        firebase_admin.initialize_app(
            options={"projectId": settings.firebase_project_id},
        )
        log.info("firebase-admin initialised (project=%s)", settings.firebase_project_id)
    except Exception:  # pragma: no cover — boot-time diagnostic only
        log.exception("firebase-admin failed to initialise")
        raise


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": 'Bearer realm="vanij-ai"'},
    )


async def require_auth(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> AuthenticatedUser:
    """FastAPI dependency: verifies the Bearer token and returns the user.

    Raises ``HTTP 401`` if the token is missing, malformed, expired, or
    issued to a different Firebase project.
    """
    # Local-dev escape hatch — refuse to run in production.
    if settings.auth_disabled:
        if settings.is_production:
            raise _unauthorized("auth_disabled is not allowed in production")
        user = AuthenticatedUser(
            uid=settings.auth_test_uid,
            email=None,
            email_verified=False,
        )
        request.state.uid = user.uid
        return user

    if credentials is None or credentials.scheme.lower() != "bearer":
        raise _unauthorized("missing bearer token")
    token = credentials.credentials
    if not token:
        raise _unauthorized("empty bearer token")

    try:
        claims = fb_auth.verify_id_token(
            token,
            check_revoked=False,
        )
    except fb_auth.ExpiredIdTokenError as err:
        raise _unauthorized("token expired") from err
    except fb_auth.RevokedIdTokenError as err:
        raise _unauthorized("token revoked") from err
    except fb_auth.InvalidIdTokenError as err:
        raise _unauthorized("invalid token") from err
    except ValueError as err:
        raise _unauthorized("malformed token") from err

    uid = claims.get("uid") or claims.get("sub")
    if not uid:
        raise _unauthorized("token missing uid")

    user = AuthenticatedUser(
        uid=uid,
        email=claims.get("email"),
        email_verified=bool(claims.get("email_verified", False)),
    )
    request.state.uid = user.uid
    return user
