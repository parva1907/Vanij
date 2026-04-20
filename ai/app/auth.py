"""Firebase Auth middleware.

Every request to a protected route must carry a valid Firebase ID token
in the ``Authorization: Bearer <jwt>`` header. The token is verified via
``firebase-admin``; on success the verified ``uid`` is attached to
``request.state.uid`` and exposed through the
:func:`require_auth` FastAPI dependency.

Sprint 7 also exposes :func:`require_agent_caller`, which accepts either
a Firebase ID token **or** a Google-signed service-account ID token
issued to the Cloud Function that bridges Firestore messages to this
service. The SA path is gated by allow-listing one email
(``settings.agent_function_sa_email``) and, when configured, the
expected ``aud`` claim.

Security notes:
  * We never log the raw token — only the ``uid`` after verification.
  * ``auth_disabled=true`` is honoured only outside production (guarded
    by :attr:`~app.config.Settings.is_production`).
  * ``firebase-admin`` is initialised lazily so unit tests can opt-out
    without needing a service account credential.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass

import firebase_admin
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth as fb_auth

from app.config import settings

log = logging.getLogger("vanij.auth")


async def _merchant_rate_limit_uid(request: Request, fallback: str) -> str:
    """Peek the JSON body and return the ``merchantId`` it declares.

    Service-account callers (our Cloud Function) pass different
    ``merchantId`` values on every request, so the rate-limit bucket
    has to key on that field — not on the SA's own email, which
    would collapse every merchant into a single shared quota.

    The body bytes are cached on the ``Request`` object by Starlette,
    so FastAPI's Pydantic body parser downstream still sees the same
    JSON we read here. Failure modes (non-JSON, empty body, missing
    field) fall back to ``fallback`` so the rate limiter degrades
    safely rather than raising before authz.
    """
    try:
        raw = await request.body()
        if not raw:
            return fallback
        data = json.loads(raw.decode("utf-8"))
    except (ValueError, UnicodeDecodeError):
        return fallback
    if not isinstance(data, dict):
        return fallback
    candidate = data.get("merchantId") or data.get("merchant_id")
    if isinstance(candidate, str) and candidate:
        return candidate
    return fallback


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


# ---------------------------------------------------------------------------
# Sprint 7 — agent-endpoint auth: Firebase *or* Cloud Function SA token.
# ---------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class AgentCaller:
    """Who called ``/v1/agent/draft``.

    ``kind`` is either:
      * ``"firebase"`` — merchant's Firebase ID token. ``uid`` is the
        verified merchant uid; the router must check that the request
        body's ``merchantId`` equals this uid.
      * ``"service"``  — Google-signed token from the Cloud Function.
        ``uid`` is set to the allow-listed SA email so logs stay
        readable; the router trusts the body's ``merchantId`` because
        only our own Function can mint this token.
    """

    kind: str  # "firebase" | "service"
    uid: str
    email: str | None

    @property
    def trusts_body_merchant_id(self) -> bool:
        return self.kind == "service"


def _verify_google_id_token(token: str) -> dict[str, object] | None:
    """Return the verified claims, or ``None`` if this isn't a valid
    Google-signed ID token for our allow-listed SA.

    Returning ``None`` (rather than raising) lets the caller fall
    through to the Firebase verifier — the two token issuers share the
    ``Authorization: Bearer`` header so we can't tell them apart up
    front without parsing.
    """
    if not settings.agent_function_sa_email:
        return None
    try:
        # Imported lazily so unit tests that never exercise this path
        # don't need ``google-auth`` wired up.
        from google.auth.transport import requests as ga_requests
        from google.oauth2 import id_token as ga_id_token
    except Exception:  # pragma: no cover — dep missing in dev shells
        log.warning("google-auth not importable; skipping SA token verify")
        return None

    audience = settings.agent_audience or None
    try:
        from google.auth import exceptions as ga_exceptions
    except Exception:  # pragma: no cover — dep missing in dev shells
        log.warning("google-auth.exceptions not importable; skipping SA token verify")
        return None
    try:
        claims: dict[str, object] = ga_id_token.verify_oauth2_token(
            token,
            ga_requests.Request(),
            audience=audience,
        )
    except (ValueError, ga_exceptions.GoogleAuthError):
        # ``ValueError`` / ``MalformedError`` cover token-format failures;
        # ``TransportError`` covers Google's JWKS fetch going down. Both
        # should fall through to the Firebase verifier rather than 500.
        return None

    email = claims.get("email")
    email_verified = bool(claims.get("email_verified", False))
    if not email_verified or email != settings.agent_function_sa_email:
        log.warning(
            "agent SA token rejected: email=%s verified=%s",
            email,
            email_verified,
        )
        return None

    return claims


async def require_agent_caller(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> AgentCaller:
    """FastAPI dependency for ``/v1/agent/draft``.

    Accepts either a Firebase ID token or a Google SA ID token from
    the allow-listed Cloud Function. Raises ``HTTP 401`` otherwise.
    """
    if settings.auth_disabled:
        if settings.is_production:
            raise _unauthorized("auth_disabled is not allowed in production")
        caller = AgentCaller(
            kind="firebase",
            uid=settings.auth_test_uid,
            email=None,
        )
        request.state.uid = caller.uid
        return caller

    if credentials is None or credentials.scheme.lower() != "bearer":
        raise _unauthorized("missing bearer token")
    token = credentials.credentials
    if not token:
        raise _unauthorized("empty bearer token")

    # Try the SA path first — it short-circuits on malformed / wrong
    # audience / wrong email without side effects.
    sa_claims = _verify_google_id_token(token)
    if sa_claims is not None:
        caller = AgentCaller(
            kind="service",
            uid=str(sa_claims.get("email", "cloud-function")),
            email=str(sa_claims.get("email")) if sa_claims.get("email") else None,
        )
        # Rate-limit bucket must be per-merchant, not per-SA. Peek the
        # body to pull ``merchantId`` and stash it on ``request.state``.
        # Starlette caches the bytes internally, so FastAPI's body
        # parser downstream still sees the same JSON.
        request.state.uid = await _merchant_rate_limit_uid(request, caller.uid)
        return caller

    # Fall back to Firebase user token.
    try:
        claims = fb_auth.verify_id_token(token, check_revoked=False)
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

    caller = AgentCaller(kind="firebase", uid=str(uid), email=claims.get("email"))
    request.state.uid = caller.uid
    return caller
