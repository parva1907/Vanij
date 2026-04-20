"""Regression tests for structured logging + request-ID middleware.

Covers:
- JSON-formatted output
- Correlation-ID propagation (inbound header honoured + echoed back)
- PII redaction — customer message body / upi_ref / phone must never
  surface as a log value even if a careless caller stuffs them into
  ``extra={...}``.
"""

from __future__ import annotations

import io
import json
import logging

import pytest

from app.logging_setup import (
    JsonFormatter,
    configure_logging,
    redact,
    request_id_var,
)


@pytest.fixture
def json_log_stream():
    """Swap the root logger's handler for one writing into a StringIO
    buffer so assertions can inspect emitted lines. Restores state so
    subsequent tests get the normal stdout logger back."""
    stream = io.StringIO()
    root = logging.getLogger()
    saved_handlers = list(root.handlers)
    saved_level = root.level
    for h in saved_handlers:
        root.removeHandler(h)
    handler = logging.StreamHandler(stream)
    handler.setFormatter(JsonFormatter())
    root.addHandler(handler)
    root.setLevel(logging.INFO)
    try:
        yield stream
    finally:
        for h in list(root.handlers):
            root.removeHandler(h)
        for h in saved_handlers:
            root.addHandler(h)
        root.setLevel(saved_level)


def _lines(stream: io.StringIO) -> list[dict]:
    """Parse every line the stream has buffered as JSON."""
    stream.seek(0)
    out: list[dict] = []
    for line in stream.read().splitlines():
        if not line.strip():
            continue
        out.append(json.loads(line))
    return out


def test_formatter_emits_json_with_core_fields(json_log_stream):
    log = logging.getLogger("vanij.test")
    log.info("hello world", extra={"foo": "bar"})

    [record] = _lines(json_log_stream)
    assert record["severity"] == "INFO"
    assert record["message"] == "hello world"
    assert record["logger"] == "vanij.test"
    assert record["foo"] == "bar"
    assert "timestamp" in record


def test_formatter_redacts_pii_keys_in_extra(json_log_stream):
    """Any field whose *key* matches the PII allow-list is redacted
    regardless of the value type."""
    log = logging.getLogger("vanij.test")
    log.info(
        "auth check",
        extra={
            "uid_safe": "abc123",
            "phone": "+911234567890",  # must be scrubbed
            "customer_message": "hi mam saree chahiye",  # must be scrubbed
            "upi_ref": "txn12345",  # must be scrubbed
            "authorization": "Bearer secretsecretsecret",  # must be scrubbed
            "latency_ms": 42,
        },
    )

    [record] = _lines(json_log_stream)
    assert record["phone"] == "[REDACTED]"
    assert record["customer_message"] == "[REDACTED]"
    assert record["upi_ref"] == "[REDACTED]"
    assert record["authorization"] == "[REDACTED]"
    assert record["uid_safe"] == "abc123"
    assert record["latency_ms"] == 42


def test_formatter_scrubs_nested_pii(json_log_stream):
    """Redaction walks nested dicts/lists so ``extra={"meta":
    {"phone": ...}}`` can't sneak through."""
    log = logging.getLogger("vanij.test")
    log.info(
        "payload",
        extra={
            "meta": {"phone": "+911234567890", "note": "ok"},
            "items": [{"upi_ref": "leak"}, {"ok": True}],
        },
    )

    [record] = _lines(json_log_stream)
    assert record["meta"] == {"phone": "[REDACTED]", "note": "ok"}
    assert record["items"] == [{"upi_ref": "[REDACTED]"}, {"ok": True}]


def test_formatter_includes_request_id_from_contextvar(json_log_stream):
    log = logging.getLogger("vanij.test")
    token = request_id_var.set("req-abc-123")
    try:
        log.info("with id")
    finally:
        request_id_var.reset(token)

    [record] = _lines(json_log_stream)
    assert record["request_id"] == "req-abc-123"


def test_redact_helper_is_pure():
    """The helper is exported for rare non-``extra`` use cases; it
    shouldn't mutate its input."""
    original = {
        "phone": "+911234567890",
        "ok": "keep",
        "nested": {"upi_ref": "abc"},
    }
    scrubbed = redact(original)
    assert scrubbed["phone"] == "[REDACTED]"
    assert scrubbed["nested"]["upi_ref"] == "[REDACTED]"
    # Original is untouched.
    assert original["phone"] == "+911234567890"
    assert original["nested"]["upi_ref"] == "abc"


def test_middleware_mints_id_and_echoes_header(client):
    configure_logging()
    resp = client.get("/health")
    assert resp.status_code == 200
    assert "x-request-id" in resp.headers
    # UUIDv4 has 36 chars (32 hex + 4 dashes)
    assert len(resp.headers["x-request-id"]) == 36


def test_middleware_honours_inbound_header(client):
    configure_logging()
    inbound = "trace-xyz-test"
    resp = client.get("/health", headers={"X-Request-ID": inbound})
    assert resp.headers["x-request-id"] == inbound
