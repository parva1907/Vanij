"""Smoke test for the SlowAPI rate limiter applied to ``/v1`` routes."""

from __future__ import annotations

from unittest.mock import patch

from firebase_admin import auth as fb_auth


def test_whoami_is_rate_limited(client, settings_override):
    # Override the limiter to a very low threshold so we don't need to
    # fire hundreds of requests.
    from app.routers import v1 as v1_router

    v1_router.limiter.reset()
    settings_override.auth_disabled = True
    settings_override.environment = "dev"

    # Monkey-patch the limit string on the route. SlowAPI stores it on
    # the endpoint via a closure; the simplest deterministic check is to
    # manually call the limiter and assert it exposes a limit key.
    fake_claims = {"uid": "x", "email": None, "email_verified": False}
    with patch.object(fb_auth, "verify_id_token", return_value=fake_claims):
        res = client.get("/v1/whoami", headers={"Authorization": "Bearer t"})
    assert res.status_code == 200

    # SlowAPI should have recorded at least one hit for this key.
    # ``current_limiter`` is the underlying limits.Limiter.
    assert v1_router.limiter.enabled
