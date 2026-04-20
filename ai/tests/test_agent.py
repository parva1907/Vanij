"""Tests for ``/v1/agent/draft`` + supporting modules (Sprint 7).

The Anthropic client and Firestore fetcher are both injected via
``app.state``; no real network call is ever made from CI. We verify:

* Auth — 401 without token, 401 with a malformed token, 200 under
  ``AUTH_DISABLED=true``, 200 under a simulated SA token, 403 when a
  Firebase caller's uid doesn't match the body's ``merchantId``.
* Prompt — inventory + history + message lines are assembled in a
  stable, documented layout.
* Response shape — ``draft`` is clipped to ``agent_max_reply_chars``;
  ``model`` / ``latencyMs`` / ``inventoryItemsUsed`` populated.
* Read-only contract — the fetcher never receives a write handle.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from app.agent.claude import LlmReply
from app.agent.inventory import InventorySummary
from app.agent.prompt import build_user_message
from app.agent.schemas import AgentHistoryTurn
from app.routers import agent as agent_router

# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------


@dataclass
class StubInventoryFetcher:
    items: list[InventorySummary] = field(default_factory=list)
    calls: list[tuple[str, int]] = field(default_factory=list)
    raise_on_fetch: Exception | None = None

    def fetch(self, merchant_id: str, limit: int) -> list[InventorySummary]:
        self.calls.append((merchant_id, limit))
        if self.raise_on_fetch is not None:
            raise self.raise_on_fetch
        return list(self.items)


@dataclass
class StubLlmClient:
    reply_text: str = (
        "Hello! That shade of saree is available. — reviewed by merchant before sending."
    )
    model: str = "claude-sonnet-test"
    latency_ms: int = 123
    raise_on_complete: Exception | None = None
    last_system: str | None = None
    last_user_message: str | None = None
    last_max_tokens: int | None = None

    def complete(self, *, system: str, user_message: str, max_tokens: int) -> LlmReply:
        self.last_system = system
        self.last_user_message = user_message
        self.last_max_tokens = max_tokens
        if self.raise_on_complete is not None:
            raise self.raise_on_complete
        return LlmReply(
            text=self.reply_text,
            model=self.model,
            latency_ms=self.latency_ms,
        )


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def agent_client(settings_override: Any) -> Any:
    """TestClient with the agent deps injected via ``app.state``."""
    settings_override.auth_disabled = True
    settings_override.environment = "test"
    # Raise the rate limit cap so the test suite never hits it.
    settings_override.agent_rate_limit = "1000/minute"

    fetcher = StubInventoryFetcher(
        items=[
            InventorySummary(
                name="Banarasi Silk Saree",
                category="Saree",
                price=4500.0,
                low_stock=True,
                colors=["Red", "Gold"],
                sizes=["Free"],
                total_quantity=2,
            ),
            InventorySummary(
                name="Cotton Kurta",
                category="Kurta",
                price=1200.0,
                low_stock=False,
                colors=["White", "Beige"],
                sizes=["M", "L"],
                total_quantity=12,
            ),
        ]
    )
    llm = StubLlmClient()

    with patch("app.auth.init_firebase_admin"):
        from app.main import app

        app.state.inventory_fetcher = fetcher
        app.state.llm_client = llm

        with TestClient(app) as c:
            c.fetcher = fetcher  # type: ignore[attr-defined]
            c.llm = llm  # type: ignore[attr-defined]
            yield c

        # Clear between tests so fixtures stay isolated.
        app.state.inventory_fetcher = None
        app.state.llm_client = None


# ---------------------------------------------------------------------------
# Prompt builder
# ---------------------------------------------------------------------------


def test_prompt_includes_inventory_history_and_message() -> None:
    items = [
        InventorySummary(
            name="Silk Saree",
            category="Saree",
            price=4500.0,
            low_stock=True,
            colors=["Red"],
            sizes=["Free"],
            total_quantity=2,
        ),
    ]
    history = [
        AgentHistoryTurn(sender="customer", body="Do you have red sarees?"),
        AgentHistoryTurn(sender="merchant", body="Yes ma'am, one moment."),
    ]
    out = build_user_message(
        customer_message="Kitne ka hai?",
        inventory=items,
        history=history,
    )
    assert "INVENTORY:" in out
    assert "Silk Saree" in out
    assert "low stock" in out
    assert "₹4500" in out
    assert "RECENT CHAT" in out
    assert "customer: Do you have red sarees?" in out
    assert "CUSTOMER JUST SAID:" in out
    assert "Kitne ka hai?" in out


def test_prompt_handles_empty_inventory() -> None:
    out = build_user_message(customer_message="hello?", inventory=[], history=[])
    assert "(no items in stock yet)" in out
    assert "RECENT CHAT" not in out  # only rendered when history is non-empty


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------


def test_draft_rejects_without_token(settings_override: Any) -> None:
    settings_override.auth_disabled = False
    settings_override.environment = "test"
    settings_override.agent_rate_limit = "1000/minute"

    with patch("app.auth.init_firebase_admin"):
        from app.main import app

        with TestClient(app) as c:
            r = c.post(
                "/v1/agent/draft",
                json={
                    "merchantId": "m1",
                    "customerId": "c1",
                    "message": "hello",
                },
            )
    assert r.status_code == 401


def test_draft_rejects_mismatched_merchant_for_firebase_caller(
    settings_override: Any,
) -> None:
    # Simulate the Firebase path: auth_disabled pins uid to AUTH_TEST_UID.
    settings_override.auth_disabled = True
    settings_override.environment = "test"
    settings_override.agent_rate_limit = "1000/minute"

    with patch("app.auth.init_firebase_admin"):
        from app.main import app

        app.state.inventory_fetcher = StubInventoryFetcher()
        app.state.llm_client = StubLlmClient()
        try:
            with TestClient(app) as c:
                r = c.post(
                    "/v1/agent/draft",
                    json={
                        "merchantId": "someone-else",
                        "customerId": "c1",
                        "message": "hi",
                    },
                )
        finally:
            app.state.inventory_fetcher = None
            app.state.llm_client = None
    assert r.status_code == 403


# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------


def test_draft_returns_reply_with_shape(agent_client: Any, settings_override: Any) -> None:
    r = agent_client.post(
        "/v1/agent/draft",
        json={
            "merchantId": settings_override.auth_test_uid,
            "customerId": "cust1",
            "message": "Kya aapke paas red saree hai?",
        },
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert "reviewed by merchant before sending." in body["draft"]
    assert body["model"] == "claude-sonnet-test"
    assert body["latencyMs"] == 123
    assert body["inventoryItemsUsed"] == 2

    # Fetcher received the right merchant uid + respected the configured cap.
    assert agent_client.fetcher.calls == [
        (settings_override.auth_test_uid, settings_override.agent_max_inventory_items),
    ]
    # Claude received the system prompt + our composed user message.
    assert "reviewed by merchant before sending." in (agent_client.llm.last_system or "")
    assert "Banarasi Silk Saree" in (agent_client.llm.last_user_message or "")


def test_draft_clips_reply_to_max_chars(agent_client: Any, settings_override: Any) -> None:
    settings_override.agent_max_reply_chars = 40
    agent_client.llm.reply_text = "x" * 500
    r = agent_client.post(
        "/v1/agent/draft",
        json={
            "merchantId": settings_override.auth_test_uid,
            "customerId": "c",
            "message": "hi",
        },
    )
    assert r.status_code == 200
    assert len(r.json()["draft"]) <= 40
    assert r.json()["draft"].endswith("…")


def test_draft_handles_inventory_failure(agent_client: Any, settings_override: Any) -> None:
    agent_client.fetcher.raise_on_fetch = RuntimeError("boom")
    r = agent_client.post(
        "/v1/agent/draft",
        json={
            "merchantId": settings_override.auth_test_uid,
            "customerId": "c",
            "message": "hi",
        },
    )
    assert r.status_code == 503
    assert r.json()["detail"] == "inventory unavailable"


def test_draft_handles_llm_failure(agent_client: Any, settings_override: Any) -> None:
    agent_client.llm.raise_on_complete = RuntimeError("api offline")
    r = agent_client.post(
        "/v1/agent/draft",
        json={
            "merchantId": settings_override.auth_test_uid,
            "customerId": "c",
            "message": "hi",
        },
    )
    assert r.status_code == 502
    assert r.json()["detail"] == "upstream LLM error"


# ---------------------------------------------------------------------------
# Service-account path — simulated by injecting an AgentCaller.
# ---------------------------------------------------------------------------


def test_draft_service_account_trusts_body_merchant_id(
    agent_client: Any, settings_override: Any
) -> None:
    from app.auth import AgentCaller, require_agent_caller
    from app.main import app

    sa = AgentCaller(kind="service", uid="cloud-function@vanij.iam", email="cf@x")

    async def _override() -> AgentCaller:
        return sa

    app.dependency_overrides[require_agent_caller] = _override
    try:
        r = agent_client.post(
            "/v1/agent/draft",
            json={
                "merchantId": "any-merchant-uid-the-function-picked",
                "customerId": "c",
                "message": "hi",
            },
        )
    finally:
        app.dependency_overrides.pop(require_agent_caller, None)
    assert r.status_code == 200, r.text
    assert agent_client.fetcher.calls[-1][0] == "any-merchant-uid-the-function-picked"


def test_sa_rate_limit_keys_on_body_merchant_id_not_sa_email(
    settings_override: Any,
) -> None:
    """Regression: the rate-limit bucket for SA callers must key on the
    ``merchantId`` in the body, not the SA email. Otherwise every merchant
    shares a single quota and one busy merchant can starve everyone else."""
    settings_override.auth_disabled = False
    settings_override.environment = "test"
    settings_override.agent_function_sa_email = "cf@vanij.iam"
    # Very tight cap so a second call from the same bucket would 429.
    settings_override.agent_rate_limit = "1/minute"

    fake_claims = {"email": "cf@vanij.iam", "email_verified": True}

    with (
        patch("app.auth.init_firebase_admin"),
        patch("app.auth._verify_google_id_token", return_value=fake_claims),
    ):
        from app.main import app

        fetcher = StubInventoryFetcher()
        llm = StubLlmClient()
        app.state.inventory_fetcher = fetcher
        app.state.llm_client = llm
        try:
            with TestClient(app) as c:
                r1 = c.post(
                    "/v1/agent/draft",
                    headers={"Authorization": "Bearer sa-token"},
                    json={
                        "merchantId": "merchant-A",
                        "customerId": "c1",
                        "message": "hi",
                    },
                )
                r2 = c.post(
                    "/v1/agent/draft",
                    headers={"Authorization": "Bearer sa-token"},
                    json={
                        "merchantId": "merchant-B",
                        "customerId": "c1",
                        "message": "hi",
                    },
                )
                # Same merchant as r1 → should exhaust merchant-A's bucket.
                r3 = c.post(
                    "/v1/agent/draft",
                    headers={"Authorization": "Bearer sa-token"},
                    json={
                        "merchantId": "merchant-A",
                        "customerId": "c2",
                        "message": "hi",
                    },
                )
        finally:
            app.state.inventory_fetcher = None
            app.state.llm_client = None

    assert r1.status_code == 200, r1.text
    # A different merchant must NOT be blocked by merchant-A's usage.
    assert r2.status_code == 200, r2.text
    assert r3.status_code == 429, r3.text


# ---------------------------------------------------------------------------
# Read-only contract — smoke check: the fetcher interface has no write
# shape. If someone adds a write method to ``InventoryFetcher``, this
# test will trip.
# ---------------------------------------------------------------------------


def test_inventory_fetcher_protocol_is_read_only() -> None:
    from app.agent import inventory as inv_mod

    forbidden = {"set", "update", "delete", "write", "create"}
    attrs = {a for a in dir(inv_mod.InventoryFetcher) if not a.startswith("_")}
    assert forbidden.isdisjoint(attrs), (
        f"InventoryFetcher grew a write-side method: {attrs & forbidden}"
    )


# ---------------------------------------------------------------------------
# Clip / token helpers
# ---------------------------------------------------------------------------


def test_clip_leaves_short_text_alone() -> None:
    assert agent_router._clip("hello", 100) == "hello"


def test_clip_truncates_with_ellipsis() -> None:
    out = agent_router._clip("hello world", 6)
    assert len(out) == 6
    assert out.endswith("…")


def test_chars_to_tokens_has_sensible_floor() -> None:
    assert agent_router._chars_to_tokens(10) >= 64
    assert agent_router._chars_to_tokens(900) > 64
