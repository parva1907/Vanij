"""HTTP middlewares for the Vanij AI backend."""

from __future__ import annotations

import logging
import time
import uuid

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.logging_setup import request_id_var, uid_var

log = logging.getLogger("vanij.http")


class RequestIdMiddleware(BaseHTTPMiddleware):
    """Assign a correlation ID to every request, log its lifecycle, and
    echo the ID back as ``X-Request-ID`` so Cloud Run logs and a
    merchant's support ticket can be joined 1:1.

    - Honours an inbound ``X-Request-ID`` header if the caller (e.g. the
      Cloud Function trigger) has already minted one. Otherwise mints a
      fresh UUIDv4.
    - Sets the ``request_id`` contextvar for the lifetime of the
      request; :class:`app.logging_setup.JsonFormatter` reads it to tag
      every log line emitted during the request.
    - Logs a single structured ``http_request`` line on completion with
      method, path, status, and latency_ms — nothing from the body.
    """

    HEADER = "x-request-id"

    async def dispatch(self, request: Request, call_next):
        raw = request.headers.get(self.HEADER) or str(uuid.uuid4())
        rid_token = request_id_var.set(raw)
        uid_token = uid_var.set(None)
        start = time.perf_counter()
        status_code = 500
        try:
            response: Response = await call_next(request)
            status_code = response.status_code
            response.headers[self.HEADER] = raw
            return response
        finally:
            elapsed_ms = int((time.perf_counter() - start) * 1000)
            # Refresh uid contextvar from request state — auth middleware
            # sets ``request.state.uid`` after this middleware has
            # already started the request.
            uid = getattr(request.state, "uid", None)
            if uid:
                uid_var.set(uid)
            log.info(
                "http_request",
                extra={
                    "method": request.method,
                    "path": request.url.path,
                    "status": status_code,
                    "latency_ms": elapsed_ms,
                },
            )
            request_id_var.reset(rid_token)
            uid_var.reset(uid_token)
