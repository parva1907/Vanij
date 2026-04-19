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


@pytest.fixture
def settings_override() -> Iterator[Any]:
    """Mutate ``app.config.settings`` for the duration of a test."""
    from app.config import settings

    snapshot = {
        "auth_disabled": settings.auth_disabled,
        "environment": settings.environment,
        "default_rate_limit": settings.default_rate_limit,
        "max_image_bytes": settings.max_image_bytes,
        "vision_backend": settings.vision_backend,
    }
    yield settings
    for k, v in snapshot.items():
        setattr(settings, k, v)
