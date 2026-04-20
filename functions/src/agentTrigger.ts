// ============================================================
// Vanij — Firestore onCreate trigger for CRM agent drafts.
//
// When a customer writes into
//   merchants/{merchantId}/customers/{customerId}/messages/{messageId}
// with `sender == "customer"`, we:
//   1. Fetch the last N messages for thin conversational context.
//   2. Call the FastAPI /v1/agent/draft endpoint (which owns Claude +
//      the prompt + merchant-scoped inventory reads).
//   3. Append the returned draft back to the same subcollection as
//      `sender: "agent", isDraft: true`.
//
// Why write from the Function instead of from FastAPI:
//   • Cloud Functions use the Firebase Admin SDK which already has
//     write credentials. FastAPI has Admin SDK too, but keeping the
//     write path here lets us trivially reason that the LLM service
//     has *no* Firestore write handle in code (spec rule #4).
//   • Retries / idempotency are easier to reason about when the
//     trigger owns the write.
//
// Idempotency: if the function is retried we set
// `agentDraftFromMessageId = sourceMessageId` on the drafted doc and
// a guard clause short-circuits if one already exists.
// ============================================================
import {getFirestore, FieldValue, type Firestore} from "firebase-admin/firestore";
import {onDocumentCreated, type FirestoreEvent, type QueryDocumentSnapshot} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";

import {AgentDraftClient, type AgentHistoryTurn} from "./agentDraft";
import {loadAgentConfig} from "./agentConfig";

const MESSAGE_PATH = "merchants/{merchantId}/customers/{customerId}/messages/{messageId}";

/**
 * Max messages fed into the agent's conversational context. Kept small
 * for prompt hygiene — Claude does better with recent turns than a
 * long transcript.
 */
const HISTORY_LIMIT = 6;

type MessageDoc = {
  sender?: string;
  body?: string;
  createdAt?: FirebaseFirestore.Timestamp;
};

export interface HandleMessageDeps {
  firestore: Firestore;
  client: AgentDraftClient;
  now?: () => Date;
}

/**
 * Core trigger body, extracted so it's unit-testable without the
 * Firebase Functions runtime. Callers inject their Firestore client
 * and agent client.
 */
export async function handleCustomerMessageCreated(
  deps: HandleMessageDeps,
  params: {merchantId: string; customerId: string; messageId: string},
  data: MessageDoc,
): Promise<"skipped" | "drafted"> {
  const sender = (data.sender ?? "").toLowerCase();
  const body = (data.body ?? "").trim();
  if (sender !== "customer") return "skipped";
  if (!body) return "skipped";

  const {merchantId, customerId, messageId} = params;
  const messagesRef = deps.firestore
    .collection("merchants")
    .doc(merchantId)
    .collection("customers")
    .doc(customerId)
    .collection("messages");

  // Idempotency guard — if a previous invocation already drafted a
  // reply for this source message, bail out.
  const existing = await messagesRef
    .where("agentDraftFromMessageId", "==", messageId)
    .limit(1)
    .get();
  if (!existing.empty) {
    logger.info("agent.trigger.idempotent_skip", {merchantId, customerId, messageId});
    return "skipped";
  }

  // Pull the most recent turns for context (excluding the message we
  // just got — the agent endpoint wires that in separately).
  const historySnap = await messagesRef
    .orderBy("createdAt", "desc")
    .limit(HISTORY_LIMIT + 1)
    .get();
  const history: AgentHistoryTurn[] = historySnap.docs
    .filter((d) => d.id !== messageId)
    .slice(0, HISTORY_LIMIT)
    .reverse()
    .map((d) => {
      const raw = d.data() as MessageDoc;
      const s = (raw.sender ?? "merchant").toLowerCase();
      const senderValue: AgentHistoryTurn["sender"] =
        s === "customer" || s === "agent" ? s : "merchant";
      return {sender: senderValue, body: (raw.body ?? "").slice(0, 2000)};
    })
    .filter((t) => t.body.length > 0);

  let draft;
  try {
    draft = await deps.client.draft({
      merchantId,
      customerId,
      message: body,
      history,
    });
  } catch (err) {
    logger.error("agent.trigger.draft_failed", {
      merchantId,
      customerId,
      messageId,
      error: (err as Error).message,
    });
    // Swallow: failing loud here would crash the trigger and Firestore
    // would retry with the same body, burning Anthropic budget. The
    // merchant will still see the customer's message and can reply
    // manually.
    return "skipped";
  }

  const draftRef = messagesRef.doc();
  await draftRef.set({
    sender: "agent",
    body: draft.draft,
    isDraft: true,
    agentModel: draft.model,
    agentLatencyMs: draft.latencyMs,
    agentInventoryItemsUsed: draft.inventoryItemsUsed,
    agentDraftFromMessageId: messageId,
    createdAt: FieldValue.serverTimestamp(),
  });

  // Bump the parent customer's lastMessageAt / updatedAt so the list
  // view re-sorts (mirrors Flutter ChatRepository.sendMessage behaviour).
  await deps.firestore
    .collection("merchants")
    .doc(merchantId)
    .collection("customers")
    .doc(customerId)
    .update({
      lastMessageAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

  logger.info("agent.trigger.drafted", {
    merchantId,
    customerId,
    messageId,
    draftId: draftRef.id,
    chars: draft.draft.length,
  });
  return "drafted";
}

type MessageEvent = FirestoreEvent<
  QueryDocumentSnapshot | undefined,
  {merchantId: string; customerId: string; messageId: string}
>;

/** Exported Cloud Function. Lazy-initialises the agent client on first
 * invocation so cold starts without any customer traffic stay cheap. */
export const onCustomerMessageCreated = onDocumentCreated(
  {
    document: MESSAGE_PATH,
    region: "asia-south1",
  },
  async (event: MessageEvent): Promise<void> => {
    const config = loadAgentConfig();
    if (!config.enabled) {
      logger.info("agent.trigger.disabled");
      return;
    }
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() as MessageDoc;
    const params = event.params;
    const client = new AgentDraftClient({config});
    await handleCustomerMessageCreated(
      {firestore: getFirestore(), client},
      params,
      data,
    );
  },
);
