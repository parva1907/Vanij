"""Tests for the ``/v1/vision/tag`` endpoint and the heuristic tagger."""

from __future__ import annotations

import io

import pytest

from app.vision.tagger import HeuristicVisionTagger

# ---------------------------------------------------------------------------
# Tagger unit tests
# ---------------------------------------------------------------------------


def test_heuristic_tagger_is_deterministic():
    tagger = HeuristicVisionTagger()
    payload = b"\x89PNG\r\n\x1a\n" + (b"vanij" * 64)
    first = tagger.tag(payload, "image/png")
    second = tagger.tag(payload, "image/png")
    assert first == second


def test_heuristic_tagger_rejects_empty_bytes():
    tagger = HeuristicVisionTagger()
    with pytest.raises(ValueError):
        tagger.tag(b"", "image/webp")


def test_heuristic_tagger_rejects_unsupported_mime():
    tagger = HeuristicVisionTagger()
    with pytest.raises(ValueError):
        tagger.tag(b"not-an-image", "application/octet-stream")


def test_heuristic_tagger_categories_match_flutter_client():
    """Every category the tagger can emit must exist in the Flutter
    ``kInventoryCategories`` list — otherwise the TagConfirmScreen
    falls back to the first category silently and the merchant sees
    the wrong suggestion pre-filled.
    """
    import re
    from pathlib import Path

    from app.vision.tagger import _CATEGORIES  # type: ignore[attr-defined]

    chips_path = (
        Path(__file__).resolve().parents[2]
        / "app"
        / "lib"
        / "features"
        / "inventory"
        / "presentation"
        / "widgets"
        / "filter_chips_bar.dart"
    )
    src = chips_path.read_text()
    match = re.search(r"kInventoryCategories\s*=\s*\[([^\]]+)\]", src)
    assert match, "could not locate kInventoryCategories in Flutter source"
    flutter_categories = tuple(re.findall(r"'([^']+)'", match.group(1)))
    assert set(_CATEGORIES) <= set(flutter_categories), (
        f"Python tagger categories {set(_CATEGORIES) - set(flutter_categories)!r} "
        f"are not present in Flutter kInventoryCategories {flutter_categories!r}"
    )


def test_heuristic_tagger_shape_matches_schema():
    tagger = HeuristicVisionTagger()
    resp = tagger.tag(b"\xff\xd8\xff\xe0" + (b"jpeg-ish" * 32), "image/jpeg")
    assert 0.0 <= resp.category.confidence <= 1.0
    assert 1 <= len(resp.colors) <= 2
    assert resp.backend == "heuristic"
    assert resp.model_version == "heuristic-v1"


# ---------------------------------------------------------------------------
# HTTP endpoint tests — go through the full FastAPI stack
# ---------------------------------------------------------------------------


def _image_bytes(n: int = 256) -> bytes:
    # Real-looking JPEG-ish bytes (SOI marker) so the content-type check
    # on the server accepts them; the heuristic tagger doesn't decode
    # pixels.
    return b"\xff\xd8\xff\xe0\x00\x10JFIF\x00" + (b"\x00" * n)


def _files(payload: bytes, content_type: str = "image/jpeg"):
    return {"image": ("sample.jpg", io.BytesIO(payload), content_type)}


def test_vision_tag_requires_auth(client):
    # No AUTH_DISABLED escape hatch → expect 401 without a bearer token.
    res = client.post("/v1/vision/tag", files=_files(_image_bytes()))
    assert res.status_code == 401


def test_vision_tag_succeeds_with_auth_disabled(client, settings_override):
    settings_override.auth_disabled = True
    res = client.post("/v1/vision/tag", files=_files(_image_bytes()))
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["backend"] == "heuristic"
    assert "category" in body
    assert 0.0 <= body["category"]["confidence"] <= 1.0
    assert isinstance(body["colors"], list)
    assert 1 <= len(body["colors"]) <= 2


def test_vision_tag_rejects_empty_payload(client, settings_override):
    settings_override.auth_disabled = True
    res = client.post("/v1/vision/tag", files=_files(b""))
    assert res.status_code == 400
    assert "empty" in res.json()["detail"].lower()


def test_vision_tag_rejects_oversized_payload(client, settings_override):
    settings_override.auth_disabled = True
    # Shrink the cap so the test payload is compact.
    settings_override.max_image_bytes = 128
    res = client.post("/v1/vision/tag", files=_files(_image_bytes(512)))
    assert res.status_code == 413
    assert "exceeds" in res.json()["detail"].lower()


def test_vision_tag_rejects_unsupported_content_type(client, settings_override):
    settings_override.auth_disabled = True
    res = client.post(
        "/v1/vision/tag",
        files=_files(_image_bytes(), content_type="application/octet-stream"),
    )
    assert res.status_code == 415
    assert "unsupported" in res.json()["detail"].lower()


def test_vision_tag_response_deterministic_across_calls(client, settings_override):
    settings_override.auth_disabled = True
    payload = _image_bytes(1024)
    first = client.post("/v1/vision/tag", files=_files(payload)).json()
    second = client.post("/v1/vision/tag", files=_files(payload)).json()
    # Same bytes → same draft tags. Makes the TagConfirmScreen round
    # trip reproducible in integration tests.
    assert first == second
