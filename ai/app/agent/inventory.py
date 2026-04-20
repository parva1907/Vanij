"""Read-only Firestore inventory fetcher for the CRM agent.

Security: This module never exposes a Firestore write handle to the
agent. The caller gets a ``list[dict]`` of lightweight item summaries
and nothing else. If anyone ever adds a ``.set()`` or ``.update()``
call here, the agent has escaped its read-only contract and the PR
must be rejected.
"""

from __future__ import annotations

import logging
from dataclasses import asdict, dataclass
from typing import Any, Protocol

log = logging.getLogger("vanij.agent.inventory")


@dataclass(frozen=True, slots=True)
class InventorySummary:
    """Minimal per-item projection we send to the LLM."""

    name: str
    category: str
    price: float
    low_stock: bool
    colors: list[str]
    sizes: list[str]
    total_quantity: int

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class InventoryFetcher(Protocol):
    """Pluggable interface so tests can inject a stub without touching
    ``firebase-admin`` or Firestore."""

    def fetch(self, merchant_id: str, limit: int) -> list[InventorySummary]:  # pragma: no cover
        ...


class FirestoreInventoryFetcher:
    """Production implementation backed by ``firebase-admin``.

    Queries ``merchants/{merchantId}/inventory`` ordered by
    ``lowStock desc, updatedAt desc`` and maps each doc to an
    :class:`InventorySummary`. We rely on the composite index declared
    in ``firebase/firestore.indexes.json``; if the query needs a new
    index, the ``.stream()`` call will raise and the caller surfaces a
    503 — never a silent fallback.
    """

    def __init__(self, firestore_client: Any | None = None) -> None:
        self._client = firestore_client

    def _resolve_client(self) -> Any:
        if self._client is not None:
            return self._client
        # Imported lazily so unit tests that never hit Firestore don't
        # need ``firebase-admin`` credentials set up.
        from firebase_admin import firestore

        self._client = firestore.client()
        return self._client

    def fetch(self, merchant_id: str, limit: int) -> list[InventorySummary]:
        if not merchant_id or limit <= 0:
            return []
        client = self._resolve_client()
        ref = (
            client.collection("merchants")
            .document(merchant_id)
            .collection("inventory")
            .order_by("lowStock", direction="DESCENDING")
            .order_by("updatedAt", direction="DESCENDING")
            .limit(limit)
        )
        out: list[InventorySummary] = []
        for doc in ref.stream():
            data = doc.to_dict() or {}
            out.append(_summary_from_doc(data))
        return out


def _summary_from_doc(data: dict[str, Any]) -> InventorySummary:
    raw_qty = data.get("quantity")
    qty_map: dict[str, Any] = raw_qty if isinstance(raw_qty, dict) else {}
    total = 0
    for v in qty_map.values():
        if isinstance(v, int | float):
            total += int(v)
    colors_raw = data.get("color")
    sizes_raw = data.get("size")
    return InventorySummary(
        name=_string(data.get("name")),
        category=_string(data.get("category")),
        price=_float(data.get("price")),
        low_stock=bool(data.get("lowStock", False)),
        colors=[_string(c) for c in colors_raw] if isinstance(colors_raw, list) else [],
        sizes=[_string(s) for s in sizes_raw] if isinstance(sizes_raw, list) else [],
        total_quantity=total,
    )


def _string(v: Any) -> str:
    return v if isinstance(v, str) else ""


def _float(v: Any) -> float:
    if isinstance(v, int | float):
        return float(v)
    return 0.0
