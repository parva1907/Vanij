"""Pluggable clothing image tagger backends.

Two implementations ship out of the box:

* :class:`HeuristicVisionTagger` — deterministic, pure-Python stub used
  by CI and local dev. Derives category / colour candidates from a
  hash of the image bytes so results are stable across runs but
  obviously not accurate. Lets us wire the whole HTTP round-trip end
  to end without shipping a 500 MB PyTorch image.

* A real PyTorch-backed backend is intentionally *not* in this file.
  When :envvar:`VISION_BACKEND` is set to ``torch`` we refuse to boot
  unless an optional extras-install of torch + torchvision is present;
  loading the model happens inside the FastAPI lifespan so the cold
  start cost is paid once per instance (per spec rule "load ML model
  once at startup, not per request").
"""

from __future__ import annotations

import hashlib
import logging
from typing import Protocol

from app.config import settings
from app.vision.schemas import TagCandidate, VisionTagResponse

log = logging.getLogger("vanij.vision")


# ---------------------------------------------------------------------------
# Public protocol + factory
# ---------------------------------------------------------------------------


class VisionTagger(Protocol):
    """Every backend exposes the same synchronous tag() method.

    Implementations MUST be safe to call from multiple uvicorn workers
    concurrently — real PyTorch backends should run inference under
    ``torch.no_grad()`` and set the model to ``eval()`` once in the
    constructor.
    """

    backend_name: str
    model_version: str

    def tag(self, image_bytes: bytes, content_type: str) -> VisionTagResponse:
        """Return draft tag candidates for one image.

        Raises :class:`ValueError` when ``image_bytes`` is not a
        recognisable image or the content type is unsupported — the
        router translates that into HTTP 415.
        """


def load_tagger() -> VisionTagger:
    """Factory: pick a backend based on :attr:`Settings.vision_backend`.

    Called once from the FastAPI lifespan. Deferred imports keep the
    cold start of the default heuristic backend snappy — torch is
    imported only when it's actually needed.
    """
    backend = settings.vision_backend.lower()
    if backend in {"heuristic", "stub", ""}:
        tagger = HeuristicVisionTagger()
        log.info("vision tagger: %s %s", tagger.backend_name, tagger.model_version)
        return tagger
    if backend == "torch":  # pragma: no cover — optional extras
        raise RuntimeError(
            "VISION_BACKEND=torch requires installing the optional "
            "`vision` extra (pip install -e '.[vision]') and providing "
            "a loadable model checkpoint. Sprint 4 ships only the "
            "heuristic backend; the torch backend arrives in a later "
            "sprint alongside the real training pipeline."
        )
    raise RuntimeError(f"Unknown VISION_BACKEND: {backend!r}")


# ---------------------------------------------------------------------------
# Heuristic backend — deterministic stub
# ---------------------------------------------------------------------------


# Coarse taxonomy shared with the Flutter client. Must match
# ``kInventoryCategories`` in
# ``app/lib/features/inventory/presentation/widgets/filter_chips_bar.dart``
# exactly — if the tagger returns a label the client does not know, the
# TagConfirmScreen silently falls back to the first category and the
# merchant sees the wrong suggestion pre-filled.
_CATEGORIES: tuple[str, ...] = (
    "Saree",
    "Kurta",
    "Lehenga",
    "Salwar",
    "Shirt",
    "Trouser",
    "Dupatta",
    "Accessory",
)

# Fashion-oriented colour palette. Confidences are intentionally modest
# (0.55–0.7) because the merchant is always asked to confirm anyway.
_COLORS: tuple[str, ...] = (
    "Red",
    "Maroon",
    "Pink",
    "Orange",
    "Yellow",
    "Green",
    "Blue",
    "Navy",
    "Black",
    "White",
    "Beige",
    "Grey",
)

_PATTERNS: tuple[str, ...] = (
    "Solid",
    "Striped",
    "Floral",
    "Printed",
    "Embroidered",
    "Checked",
)

_ACCEPTED_MIME: frozenset[str] = frozenset({"image/webp", "image/jpeg", "image/png", "image/jpg"})


class HeuristicVisionTagger:
    """Hash-based deterministic stub.

    Two very different images can collide onto the same tag bucket —
    that's fine for a pre-production skeleton. What matters is that
    the round-trip contract (shape, confidences, backend metadata)
    exactly matches what the real PyTorch backend will return, so the
    Flutter client never needs to branch on which backend ran.
    """

    backend_name = "heuristic"
    model_version = "heuristic-v1"

    def tag(self, image_bytes: bytes, content_type: str) -> VisionTagResponse:
        if content_type not in _ACCEPTED_MIME:
            raise ValueError(f"unsupported content type: {content_type}")
        if not image_bytes:
            raise ValueError("empty image payload")

        digest = hashlib.sha256(image_bytes).digest()

        # Indices are deterministic in the image bytes but uniformly
        # distributed across the vocabularies.
        category = _CATEGORIES[digest[0] % len(_CATEGORIES)]
        primary_color = _COLORS[digest[1] % len(_COLORS)]
        # Only suggest a secondary colour half the time — mirrors real
        # clothing photography where most SKUs are monochrome.
        secondary_color = _COLORS[digest[2] % len(_COLORS)] if digest[3] & 1 else None
        pattern = _PATTERNS[digest[4] % len(_PATTERNS)]

        colors = [TagCandidate(value=primary_color, confidence=0.72)]
        if secondary_color and secondary_color != primary_color:
            colors.append(TagCandidate(value=secondary_color, confidence=0.58))

        return VisionTagResponse(
            category=TagCandidate(value=category, confidence=0.68),
            colors=colors,
            pattern=TagCandidate(value=pattern, confidence=0.55),
            name_suggestion=None,
            backend=self.backend_name,
            model_version=self.model_version,
        )
