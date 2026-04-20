"""Tests for the Firebase Auth middleware.

We never talk to real Firebase — ``firebase_admin.auth.verify_id_token``
is patched to control the verification outcome deterministically.
"""

from __future__ import annotations

from unittest.mock import patch

import pytest
from firebase_admin import auth as fb_auth


def _authed(client, token: str = "any"):
    return client.get(
        "/v1/whoami",
        headers={"Authorization": f"Bearer {token}"},
    )


def test_v1_requires_bearer_token(client):
    res = client.get("/v1/whoami")
    assert res.status_code == 401
    assert res.headers.get("www-authenticate", "").lower().startswith("bearer")


def test_v1_rejects_malformed_scheme(client):
    res = client.get("/v1/whoami", headers={"Authorization": "Basic abc123"})
    assert res.status_code in (401, 403)  # HTTPBearer returns 403 on wrong scheme


def test_v1_rejects_invalid_token(client):
    with patch.object(
        fb_auth,
        "verify_id_token",
        side_effect=fb_auth.InvalidIdTokenError("bad"),
    ):
        res = _authed(client, "bogus")
    assert res.status_code == 401
    assert res.json()["detail"] == "invalid token"


def test_v1_rejects_expired_token(client):
    with patch.object(
        fb_auth,
        "verify_id_token",
        side_effect=fb_auth.ExpiredIdTokenError("expired", cause=None),
    ):
        res = _authed(client, "expired")
    assert res.status_code == 401
    assert res.json()["detail"] == "token expired"


def test_v1_accepts_valid_token(client):
    fake_claims = {
        "uid": "merchant-123",
        "email": "owner@shop.in",
        "email_verified": True,
    }
    with patch.object(fb_auth, "verify_id_token", return_value=fake_claims):
        res = _authed(client, "goodtoken")
    assert res.status_code == 200, res.text
    body = res.json()
    assert body == {
        "uid": "merchant-123",
        "email": "owner@shop.in",
        "email_verified": True,
    }


def test_auth_disabled_in_dev_short_circuits(client, settings_override):
    settings_override.auth_disabled = True
    settings_override.environment = "dev"
    res = client.get("/v1/whoami")
    assert res.status_code == 200
    assert res.json()["uid"] == settings_override.auth_test_uid


def test_auth_disabled_forbidden_in_production(client, settings_override):
    settings_override.auth_disabled = True
    settings_override.environment = "prod"
    res = client.get("/v1/whoami")
    assert res.status_code == 401
    assert res.json()["detail"] == "auth_disabled is not allowed in production"


@pytest.mark.parametrize("scheme_token", ["", "   "])
def test_v1_rejects_empty_token(client, scheme_token):
    res = client.get(
        "/v1/whoami",
        headers={"Authorization": f"Bearer {scheme_token}"},
    )
    assert res.status_code in (401, 403)


def test_verify_google_id_token_swallows_transport_error(settings_override):
    """``TransportError`` (Google JWKS fetch failure) is not a ``ValueError``,
    so catching only ``ValueError`` would propagate it and 500 the request
    instead of falling through to Firebase verification.
    """
    settings_override.agent_function_sa_email = "cf@vanij.iam"
    from google.auth import exceptions as ga_exceptions

    from app.auth import _verify_google_id_token

    with patch(
        "google.oauth2.id_token.verify_oauth2_token",
        side_effect=ga_exceptions.TransportError("jwks unreachable"),
    ):
        assert _verify_google_id_token("any-token") is None


def test_verify_google_id_token_swallows_malformed_error(settings_override):
    """``ValueError`` (token shape wrong) still falls through, and the
    existing ``google.auth.exceptions.MalformedError`` is a subclass of
    ``ValueError`` so it's covered by the same branch."""
    settings_override.agent_function_sa_email = "cf@vanij.iam"

    from app.auth import _verify_google_id_token

    with patch(
        "google.oauth2.id_token.verify_oauth2_token",
        side_effect=ValueError("bad token"),
    ):
        assert _verify_google_id_token("any-token") is None


def test_verify_google_id_token_swallows_connection_error(settings_override):
    """``requests.exceptions.ConnectionError`` (the underlying JWKS HTTP
    call failing) is not a ``GoogleAuthError`` and not a ``ValueError``,
    but must still fall through to the Firebase verifier.
    """
    settings_override.agent_function_sa_email = "cf@vanij.iam"

    from app.auth import _verify_google_id_token

    class _FakeConnErr(OSError):
        pass

    with patch(
        "google.oauth2.id_token.verify_oauth2_token",
        side_effect=_FakeConnErr("connection refused"),
    ):
        assert _verify_google_id_token("any-token") is None
