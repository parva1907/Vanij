"""Pydantic models for the ``/v1/vision/tag`` endpoint.

The response shape is deliberately shaped for the Flutter
``TagConfirmScreen``: every field is a *candidate* that the merchant
must confirm. Per the Vanij absolute security rule, AI tags are never
auto-written to Firestore — the server returns suggestions only.
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class TagCandidate(BaseModel):
    """A single label with a confidence score in ``[0.0, 1.0]``."""

    value: str = Field(min_length=1, max_length=64)
    confidence: float = Field(ge=0.0, le=1.0)


class VisionTagResponse(BaseModel):
    """Draft tags suggested for one inventory photo.

    Fields mirror the Firestore ``inventory/{itemId}`` document so the
    Flutter side can copy them onto the form with minimal remapping.
    """

    category: TagCandidate
    colors: list[TagCandidate] = Field(default_factory=list, max_length=8)
    pattern: TagCandidate | None = None
    # Free-form text the merchant can paste into the item name. Never
    # auto-assigned, always editable.
    name_suggestion: str | None = Field(default=None, max_length=80)
    # The backend that produced these tags — useful for analytics once
    # we ship multiple models behind the same endpoint.
    backend: str = Field(min_length=1, max_length=32)
    # Model version string, e.g. "heuristic-v1" or "mobilenet_v3-2024-01".
    model_version: str = Field(min_length=1, max_length=64)
