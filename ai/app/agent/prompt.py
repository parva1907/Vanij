"""System + user prompt builders for the CRM agent.

The agent's behaviour contract (mirrored in the system prompt):

* English or Hindi code-mix — match the customer's language.
* Max 3 short sentences. Keep it conversational, not corporate.
* Only reference items that exist in the provided inventory context.
  If the customer asks about something we don't stock, say so and
  offer an alternative from the context.
* End with "— reviewed by merchant before sending." so the customer
  knows a human approved the reply.
* Never make up prices, phone numbers, or UPI IDs. No emojis.
"""

from __future__ import annotations

from app.agent.inventory import InventorySummary
from app.agent.schemas import AgentHistoryTurn

SYSTEM_PROMPT = """\
You are Vanij, the AI assistant for a small Indian fashion retailer.
Your job: draft one short reply a merchant can send back to a customer
on WhatsApp or in-store chat. The merchant will review every draft
before it goes out.

Rules (follow strictly):
1. Match the customer's language. English, Hindi, or mixed are all OK.
2. At most 3 short sentences. No greetings longer than one word.
3. Only reference items that appear in the INVENTORY block below. If
   the customer asks for something not listed, say "we don't stock
   that right now" and suggest the closest match from the list.
4. Never invent prices, phone numbers, UPI IDs, or delivery promises.
   Quote prices only as listed (in ₹).
5. Do not use emojis, markdown, links, or bullet points.
6. End every reply with the exact string:
   "— reviewed by merchant before sending."
"""


def build_user_message(
    customer_message: str,
    inventory: list[InventorySummary],
    history: list[AgentHistoryTurn],
) -> str:
    """Compose the user-turn prompt Claude sees.

    Structure (stable — tests snapshot it):

        INVENTORY:
        - <name> | <category> | ₹<price> | qty <n>[, low stock] | colors: ... | sizes: ...
        ...

        RECENT CHAT (oldest first):
        <sender>: <body>
        ...

        CUSTOMER JUST SAID:
        <message>

        Draft the merchant's reply.
    """

    lines: list[str] = []
    lines.append("INVENTORY:")
    if not inventory:
        lines.append("- (no items in stock yet)")
    else:
        for item in inventory:
            lines.append(_format_item(item))

    if history:
        lines.append("")
        lines.append("RECENT CHAT (oldest first):")
        for turn in history:
            lines.append(f"{turn.sender}: {turn.body.strip()}")

    lines.append("")
    lines.append("CUSTOMER JUST SAID:")
    lines.append(customer_message.strip())
    lines.append("")
    lines.append("Draft the merchant's reply.")
    return "\n".join(lines)


def _format_item(item: InventorySummary) -> str:
    low = ", low stock" if item.low_stock else ""
    colors = ", ".join(item.colors) if item.colors else "—"
    sizes = ", ".join(item.sizes) if item.sizes else "—"
    name = item.name or "(unnamed)"
    category = item.category or "(uncategorised)"
    return (
        f"- {name} | {category} | ₹{item.price:.0f} | "
        f"qty {item.total_quantity}{low} | colors: {colors} | sizes: {sizes}"
    )
