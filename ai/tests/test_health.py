"""Tests for the unauthenticated health + readiness probes."""

from __future__ import annotations


def test_health_returns_ok(client):
    res = client.get("/health")
    assert res.status_code == 200
    body = res.json()
    assert body["ok"] is True
    assert body["service"] == "vanij-ai"
    assert body["version"]
    assert body["environment"]
    assert isinstance(body["uptime_seconds"], int | float)


def test_ready_includes_firebase_flag(client):
    res = client.get("/ready")
    assert res.status_code == 200
    body = res.json()
    assert "firebase_admin_ready" in body
    # firebase-admin init is stubbed in tests, so readiness tracks the
    # real firebase_admin._apps dict (empty → False).
    assert isinstance(body["firebase_admin_ready"], bool)
