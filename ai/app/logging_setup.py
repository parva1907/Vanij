"""Structured JSON logging + request-ID correlation.

Cloud Run (and Cloud Logging in general) auto-parses JSON payloads on
stdout. Emitting plain text means the merchant's support tickets arrive
as opaque strings; emitting JSON means every log line is filterable by
``request_id``, ``uid``, ``path``, and ``latency_ms``.

Security guard-rails baked into the formatter:

* No field value is ever stringified by ``repr()``. Anything passed via
  ``extra={...}`` is JSON-serialised or coerced to ``str`` with
  ``default=str`` — never ``repr``, which would leak object internals.
* The two fields that could leak PII — a customer ``message`` body and
  a UPI transaction reference — are **never** logged as values. The
  existing call sites only log *lengths* and *timings*; this formatter
  plus :func:`redact` below belt-and-braces that by scrubbing any key
  named ``message``, ``body``, ``upi_ref``, ``phone``, ``email`` at
  emit time, no matter which module calls the logger.
"""

from __future__ import annotations

import contextvars
import json
import logging
from datetime import UTC, datetime
from typing import Any

# Keys whose *values* must never appear in logs even if a caller slips
# them into ``extra``. We match case-insensitively.
_PII_KEYS: frozenset[str] = frozenset(
    {
        "message",
        "body",
        "customer_message",
        "upi_ref",
        "upiref",
        "phone",
        "phone_encrypted",
        "email",
        "token",
        "authorization",
        "api_key",
    }
)

# Request-scoped correlation id. ``JsonFormatter`` reads this via
# ``contextvars.copy_context()`` so cross-await log calls still see the
# right id. ``RequestIdMiddleware`` is responsible for setting + resetting
# the value.
request_id_var: contextvars.ContextVar[str | None] = contextvars.ContextVar(
    "request_id", default=None
)
uid_var: contextvars.ContextVar[str | None] = contextvars.ContextVar("uid", default=None)


def redact(value: Any) -> Any:
    """Scrub PII-looking keys recursively. Used by the formatter on
    ``extra`` fields *before* JSON-serialising them, and also exported
    so callers can redact a dict they intend to log in the body of a
    message (rare — prefer ``extra``)."""
    if isinstance(value, dict):
        return {
            k: ("[REDACTED]" if k.lower() in _PII_KEYS else redact(v)) for k, v in value.items()
        }
    if isinstance(value, list):
        return [redact(v) for v in value]
    return value


# Attributes the stdlib always puts on every ``LogRecord``. We filter
# them out before treating the rest as user-supplied ``extra=``.
_RESERVED_LOGRECORD_KEYS = frozenset(
    {
        "name",
        "msg",
        "args",
        "levelname",
        "levelno",
        "pathname",
        "filename",
        "module",
        "exc_info",
        "exc_text",
        "stack_info",
        "lineno",
        "funcName",
        "created",
        "msecs",
        "relativeCreated",
        "thread",
        "threadName",
        "processName",
        "process",
        "asctime",
        "message",
        "taskName",
    }
)


class JsonFormatter(logging.Formatter):
    """Emit a single JSON object per log record."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.fromtimestamp(record.created, tz=UTC).isoformat(),
            "severity": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        rid = request_id_var.get()
        if rid:
            payload["request_id"] = rid
        uid = uid_var.get()
        if uid:
            payload["uid"] = uid

        # User-supplied ``extra=`` lands as arbitrary attributes on the
        # record. Copy over anything that isn't a reserved stdlib field,
        # scrubbing PII-looking keys on the way out.
        for key, value in record.__dict__.items():
            if key in _RESERVED_LOGRECORD_KEYS:
                continue
            if key.startswith("_"):
                continue
            if key.lower() in _PII_KEYS:
                payload[key] = "[REDACTED]"
            else:
                payload[key] = redact(value)

        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload, default=str, ensure_ascii=False)


def configure_logging(level: int = logging.INFO) -> None:
    """Install the JSON formatter on the root logger, replacing any
    handler that was installed earlier (idempotent — safe to call from
    both ``main`` and tests)."""
    root = logging.getLogger()
    root.setLevel(level)
    for h in list(root.handlers):
        root.removeHandler(h)
    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())
    root.addHandler(handler)
