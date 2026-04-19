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
    assert isinstance(body["firebase_admin_ready"], bool)


def test_ready_ok_when_auth_disabled_even_without_firebase(client, settings_override):
    settings_override.auth_disabled = True
    res = client.get("/ready")
    assert res.status_code == 200
    # With AUTH_DISABLED the service is ready once FastAPI has booted,
    # regardless of firebase-admin init status.
    assert res.json()["ok"] is True


def test_ready_not_ok_when_auth_enabled_and_firebase_missing(client, settings_override):
    settings_override.auth_disabled = False
    res = client.get("/ready")
    assert res.status_code == 200
    body = res.json()
    # firebase-admin init is stubbed in tests, so ``_apps`` is empty and
    # readiness must reflect that the prod-shaped config cannot serve.
    assert body["firebase_admin_ready"] is False
    assert body["ok"] is False
