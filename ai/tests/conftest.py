"""Pytest fixtures shared across the Vanij AI backend test suite.

We keep the global ``settings`` singleton mutable during tests so each
test can toggle ``auth_disabled`` / ``environment`` without re-importing
the ``app.config`` module. Firebase-admin init is bypassed entirely by
patching :func:`app.auth.init_firebase_admin`.
"""

from __future__ import annotations

import os
from collections.abc import Iterator
from typing import Any
from unittest.mock import patch

import pytest

# Must be set before `app.main` is imported for the first time.
os.environ.setdefault("AUTH_DISABLED", "false")
os.environ.setdefault("ENVIRONMENT", "test")
os.environ.setdefault("ALLOWED_ORIGINS", "https://vanij.app")


@pytest.fixture
def client() -> Iterator[Any]:
    """TestClient with firebase-admin init stubbed out.

    Imported lazily so ``os.environ`` tweaks above take effect.
    """
    from fastapi.testclient import TestClient

    with patch("app.auth.init_firebase_admin"):
        from app.main import app

        with TestClient(app) as c:
            yield c


_SNAPSHOT_FIELDS = (
    "auth_disabled",
    "environment",
    "default_rate_limit",
    "max_image_bytes",
    "vision_backend",
    # Sprint 7 — agent
    "anthropic_api_key",
    "anthropic_model",
    "agent_max_reply_chars",
    "agent_max_inventory_items",
    "agent_rate_limit",
    "agent_function_sa_email",
    "agent_audience",
)


@pytest.fixture
def settings_override() -> Iterator[Any]:
    """Mutate ``app.config.settings`` for the duration of a test.

    Every field a test might toggle must be in ``_SNAPSHOT_FIELDS``
    so its pre-test value is restored on teardown. Missing fields
    would otherwise leak between tests and break order-independent
    execution (e.g. ``pytest-randomly``).
    """
    from app.config import settings

    snapshot = {k: getattr(settings, k) for k in _SNAPSHOT_FIELDS}
    yield settings
    for k, v in snapshot.items():
        setattr(settings, k, v)
