"""LLM CRM agent (Sprint 7).

Exposes a read-only Claude Sonnet wrapper that drafts replies to a
customer's chat message given the merchant's inventory context.
Submodules:

* :mod:`app.agent.schemas`    — request / response pydantic models
* :mod:`app.agent.inventory`  — Firestore read-only inventory fetcher
* :mod:`app.agent.prompt`     — system + user prompt builders
* :mod:`app.agent.claude`     — thin Anthropic client wrapper

The agent has **no write tools**: neither the prompt nor the client can
reach Firestore with a write handle. The only path that persists the
draft back to Firestore is the Cloud Function trigger in
``functions/src/agentTrigger.ts``.
"""
