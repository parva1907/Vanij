"""``POST /v1/vision/tag`` — clothing image → draft tag candidates.

The endpoint is authentication-gated (inherited from the ``/v1``
router) and rate limited per spec rule #6. The model runs against the
tagger loaded once by the FastAPI lifespan; nothing here touches disk
or the network.

Security invariants:
  * Payload size is capped via :attr:`Settings.max_image_bytes` to
    match the 5 MB Firebase Storage rule. Oversize payloads return
    HTTP 413 before the model sees them.
  * We never persist the uploaded bytes. The image is held in memory
    only for the duration of the request.
  * Unsupported content types return HTTP 415 with a clear detail —
    we never silently best-effort.
  * Per the absolute security rule, the response is *draft only*. The
    caller must surface it through the Flutter TagConfirmScreen before
    any Firestore write.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status

from app.auth import AuthenticatedUser, require_auth
from app.config import settings
from app.routers.v1 import limiter
from app.vision.schemas import VisionTagResponse
from app.vision.tagger import VisionTagger

log = logging.getLogger("vanij.vision.router")

router = APIRouter(
    prefix="/v1/vision",
    tags=["vision"],
    dependencies=[Depends(require_auth)],
)


def get_tagger(request: Request) -> VisionTagger:
    """Dependency: resolve the tagger loaded by the lifespan."""
    tagger = getattr(request.app.state, "vision_tagger", None)
    if tagger is None:
        # The lifespan hasn't run (e.g. raw ASGI test harness that
        # skips startup events). This is a configuration error — we
        # never lazy-load the model inside a request path.
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="vision tagger not initialised",
        )
    return tagger


@router.post(
    "/tag",
    response_model=VisionTagResponse,
    status_code=status.HTTP_200_OK,
    summary="Generate draft tag candidates for a clothing photo",
)
@limiter.limit(settings.default_rate_limit)
async def tag_image(
    request: Request,  # required by SlowAPI to derive the rate-limit key
    image: UploadFile = File(..., description="Clothing photo (WebP / JPEG / PNG)"),
    user: AuthenticatedUser = Depends(require_auth),
    tagger: VisionTagger = Depends(get_tagger),
) -> VisionTagResponse:
    content_type = (image.content_type or "").lower()

    payload = await image.read()
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="empty image payload",
        )
    if len(payload) > settings.max_image_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=(f"image exceeds {settings.max_image_bytes} bytes (got {len(payload)})"),
        )

    try:
        response = tagger.tag(payload, content_type)
    except ValueError as err:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=str(err),
        ) from err

    # Log only the verified uid + backend metadata — never the bytes.
    log.info(
        "vision.tag uid=%s bytes=%d backend=%s category=%s",
        user.uid,
        len(payload),
        response.backend,
        response.category.value,
    )
    return response
