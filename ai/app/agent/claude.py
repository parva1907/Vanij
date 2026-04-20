"""Thin wrapper around the Anthropic Messages API.

Kept deliberately minimal so tests can monkey-patch ``AnthropicClient``
without pulling in the real ``anthropic`` package. The client is
**synchronous** — Anthropic's SDK ships both sync and async flavours
and the sync one is simpler to exercise from within a FastAPI route
when we don't need streaming.

Security notes:
  * The API key is read once at construction time from
    :attr:`Settings.anthropic_api_key`; never per-request, never logged,
    never returned to the caller.
  * No raw customer messages are logged — only model metadata.
"""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from typing import Any, Protocol

log = logging.getLogger("vanij.agent.claude")


@dataclass(frozen=True, slots=True)
class LlmReply:
    text: str
    model: str
    latency_ms: int


class LlmClient(Protocol):
    """Protocol the agent router depends on — unit tests inject a stub."""

    def complete(
        self,
        *,
        system: str,
        user_message: str,
        max_tokens: int,
    ) -> LlmReply:  # pragma: no cover
        ...


class AnthropicClient:
    """Production :class:`LlmClient` backed by the Anthropic SDK."""

    def __init__(self, *, api_key: str, model: str) -> None:
        if not api_key:
            raise RuntimeError("anthropic_api_key is empty — refusing to construct client")
        # Imported lazily so pytest never needs the real package on the
        # path when tests swap in a stub.
        import anthropic

        self._client = anthropic.Anthropic(api_key=api_key)
        self._model = model

    def complete(
        self,
        *,
        system: str,
        user_message: str,
        max_tokens: int,
    ) -> LlmReply:
        start = time.perf_counter()
        resp = self._client.messages.create(
            model=self._model,
            max_tokens=max_tokens,
            system=system,
            messages=[{"role": "user", "content": user_message}],
        )
        text = _extract_text(resp)
        latency_ms = int((time.perf_counter() - start) * 1000)
        log.info(
            "agent.claude model=%s latency_ms=%d chars=%d",
            self._model,
            latency_ms,
            len(text),
        )
        return LlmReply(text=text, model=self._model, latency_ms=latency_ms)


def _extract_text(resp: Any) -> str:
    """Return the concatenated text of an Anthropic Messages response."""
    content = getattr(resp, "content", None) or []
    parts: list[str] = []
    for block in content:
        t = getattr(block, "type", None)
        if t == "text":
            txt = getattr(block, "text", "")
            if isinstance(txt, str):
                parts.append(txt)
    return "".join(parts).strip()
