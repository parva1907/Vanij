"""Pydantic request / response models for ``/v1/agent/draft``."""

from __future__ import annotations

from pydantic import BaseModel, Field


class AgentDraftRequest(BaseModel):
    """Payload for a single draft generation.

    ``merchantId`` + ``customerId`` pin which tenant's inventory the
    agent may read. When the caller is authenticated with a Firebase ID
    token, ``merchantId`` must equal the verified uid — the auth layer
    enforces this; the model here only validates shape.
    """

    merchant_id: str = Field(..., min_length=1, max_length=128, alias="merchantId")
    customer_id: str = Field(..., min_length=1, max_length=128, alias="customerId")
    message: str = Field(..., min_length=1, max_length=2000)
    # Optional: last few turns of context the Function already has in
    # hand. Keeps the agent stateless — we never re-fetch it.
    history: list[AgentHistoryTurn] = Field(default_factory=list, max_length=10)

    model_config = {"populate_by_name": True}


class AgentHistoryTurn(BaseModel):
    sender: str = Field(..., pattern=r"^(merchant|customer|agent)$")
    body: str = Field(..., min_length=1, max_length=2000)


class AgentDraftResponse(BaseModel):
    """What the endpoint returns to the Cloud Function."""

    draft: str
    model: str
    latency_ms: int = Field(..., alias="latencyMs")
    # How many inventory items were actually shown to Claude. Useful
    # for debugging prompt bloat and tail-latency spikes.
    inventory_items_used: int = Field(..., alias="inventoryItemsUsed")

    model_config = {"populate_by_name": True}


AgentDraftRequest.model_rebuild()
