"""``POST /v1/agent/draft`` — LLM-drafted CRM reply.

Flow:
  1. :func:`app.auth.require_agent_caller` verifies the bearer token —
     either a Firebase merchant ID token or a Google-signed SA token
     from our Cloud Function.
  2. When the caller is a human merchant (Firebase), ``merchantId`` in
     the body must match the verified uid. Service-account callers are
     trusted to pass any ``merchantId`` — only our Function can mint
     those tokens.
  3. The inventory fetcher reads the merchant's top-N items read-only.
  4. The prompt builder composes the user turn from inventory + recent
     history + the customer's message.
  5. The Claude client generates the draft; length is capped at
     ``settings.agent_max_reply_chars``.

The endpoint never writes to Firestore. The caller (Cloud Function)
persists the draft by writing a new message doc with ``sender=agent``.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request, status
from slowapi.util import get_remote_address

from app.agent.claude import AnthropicClient, LlmClient
from app.agent.inventory import FirestoreInventoryFetcher, InventoryFetcher
from app.agent.prompt import SYSTEM_PROMPT, build_user_message
from app.agent.schemas import AgentDraftRequest, AgentDraftResponse
from app.auth import AgentCaller, require_agent_caller
from app.config import settings
from app.routers.v1 import limiter

log = logging.getLogger("vanij.agent.router")


router = APIRouter(
    prefix="/v1/agent",
    tags=["agent"],
    dependencies=[Depends(require_agent_caller)],
)


def _agent_rate_limit_key(request: Request) -> str:
    """Rate-limit bucket per merchant uid (falls back to IP for
    unauthenticated dev flows). Prevents one rude customer from
    burning another merchant's quota."""
    uid = getattr(request.state, "uid", None)
    if uid:
        return f"merchant:{uid}"
    return get_remote_address(request)


def get_inventory_fetcher(request: Request) -> InventoryFetcher:
    """Dependency: resolve the inventory fetcher attached by the
    lifespan (or a stub injected by tests)."""
    fetcher = getattr(request.app.state, "inventory_fetcher", None)
    if fetcher is None:
        fetcher = FirestoreInventoryFetcher()
        request.app.state.inventory_fetcher = fetcher
    return fetcher


def get_llm_client(request: Request) -> LlmClient:
    """Dependency: resolve the Claude client attached by the lifespan
    (or a stub injected by tests). We construct lazily on first use so
    the backend can boot even when ``ANTHROPIC_API_KEY`` is empty — the
    error surfaces as HTTP 503 on the first agent call instead of
    killing startup."""
    client = getattr(request.app.state, "llm_client", None)
    if client is not None:
        return client
    if not settings.anthropic_api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="anthropic client not configured",
        )
    client = AnthropicClient(
        api_key=settings.anthropic_api_key,
        model=settings.anthropic_model,
    )
    request.app.state.llm_client = client
    return client


@router.post(
    "/draft",
    response_model=AgentDraftResponse,
    status_code=status.HTTP_200_OK,
    summary="Draft a merchant reply to a customer's chat message.",
)
@limiter.limit(
    limit_value=lambda: settings.agent_rate_limit,
    key_func=_agent_rate_limit_key,
)
def draft_reply(
    request: Request,  # required by SlowAPI
    payload: AgentDraftRequest,
    caller: AgentCaller = Depends(require_agent_caller),
    fetcher: InventoryFetcher = Depends(get_inventory_fetcher),
    llm: LlmClient = Depends(get_llm_client),
) -> AgentDraftResponse:
    _enforce_merchant_scope(caller, payload.merchant_id)

    try:
        inventory = fetcher.fetch(
            merchant_id=payload.merchant_id,
            limit=settings.agent_max_inventory_items,
        )
    except Exception as err:
        # Read-side Firestore errors (missing index, permission) surface
        # as 503 rather than leaking stack traces.
        log.exception("inventory fetch failed uid=%s", caller.uid)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="inventory unavailable",
        ) from err

    user_message = build_user_message(
        customer_message=payload.message,
        inventory=inventory,
        history=payload.history,
    )

    max_tokens = _chars_to_tokens(settings.agent_max_reply_chars)
    try:
        reply = llm.complete(
            system=SYSTEM_PROMPT,
            user_message=user_message,
            max_tokens=max_tokens,
        )
    except Exception as err:
        log.exception("anthropic.messages.create failed uid=%s", caller.uid)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="upstream LLM error",
        ) from err

    draft = _clip(reply.text, settings.agent_max_reply_chars)
    log.info(
        "agent.draft uid=%s kind=%s merchant=%s customer=%s items=%d chars=%d latency_ms=%d",
        caller.uid,
        caller.kind,
        payload.merchant_id,
        payload.customer_id,
        len(inventory),
        len(draft),
        reply.latency_ms,
    )
    return AgentDraftResponse(
        draft=draft,
        model=reply.model,
        latencyMs=reply.latency_ms,
        inventoryItemsUsed=len(inventory),
    )


def _enforce_merchant_scope(caller: AgentCaller, merchant_id: str) -> None:
    """A Firebase-authenticated merchant can only ask about their own
    inventory. Service-account callers (our Cloud Function) are
    trusted to pass the merchant id from the Firestore trigger path."""
    if caller.trusts_body_merchant_id:
        return
    if caller.uid != merchant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="merchantId does not match authenticated user",
        )


def _clip(text: str, max_chars: int) -> str:
    return text if len(text) <= max_chars else text[: max_chars - 1].rstrip() + "…"


def _chars_to_tokens(chars: int) -> int:
    # Rough upper-bound — English averages ~4 chars/token, so we give
    # the model a little headroom. Anthropic clips to ``max_tokens``
    # regardless, so over-estimating is safe and under-estimating
    # truncates replies mid-sentence.
    return max(64, chars // 3)


# ---------------------------------------------------------------------------
# Re-exports used by tests.
# ---------------------------------------------------------------------------
__all__ = [
    "router",
    "get_inventory_fetcher",
    "get_llm_client",
    "_agent_rate_limit_key",
    "_clip",
    "_chars_to_tokens",
    "_enforce_merchant_scope",
]


def _ensure_exports(_: Any = None) -> None:  # pragma: no cover
    # Silence unused-import linting for the stub alias we re-export.
    _ = AgentDraftResponse
