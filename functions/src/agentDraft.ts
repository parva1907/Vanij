// ============================================================
// Vanij — thin HTTP client for the FastAPI /v1/agent/draft endpoint.
//
// Signs requests with a Google-issued ID token (audience = the
// FastAPI Cloud Run URL). The FastAPI service verifies the token and
// checks the signer email against its allow-list.
//
// We intentionally keep this module transport-shaped — no Firestore
// imports, no Cloud Function types. The trigger calls it; tests call
// it directly with an injected fetch stub.
// ============================================================
import {GoogleAuth, type IdTokenClient} from "google-auth-library";

import type {AgentConfig} from "./agentConfig";

export interface AgentHistoryTurn {
  sender: "merchant" | "customer" | "agent";
  body: string;
}

export interface DraftRequest {
  merchantId: string;
  customerId: string;
  message: string;
  history?: AgentHistoryTurn[];
}

export interface DraftResponse {
  draft: string;
  model: string;
  latencyMs: number;
  inventoryItemsUsed: number;
}

export type FetchLike = (
  input: string,
  init: {
    method: string;
    headers: Record<string, string>;
    body: string;
  },
) => Promise<{
  ok: boolean;
  status: number;
  text(): Promise<string>;
  json(): Promise<unknown>;
}>;

export type IdTokenProvider = (audience: string) => Promise<string>;

export interface AgentDraftClientOptions {
  config: AgentConfig;
  fetchImpl?: FetchLike;
  idTokenProvider?: IdTokenProvider;
}

export class AgentDraftClient {
  private readonly config: AgentConfig;
  private readonly fetchImpl: FetchLike;
  private readonly idTokenProvider: IdTokenProvider;

  constructor(opts: AgentDraftClientOptions) {
    this.config = opts.config;
    this.fetchImpl = opts.fetchImpl ?? ((globalThis as unknown as {fetch: FetchLike}).fetch);
    this.idTokenProvider = opts.idTokenProvider ?? defaultIdTokenProvider();
  }

  async draft(req: DraftRequest): Promise<DraftResponse> {
    if (!this.config.pythonBackendUrl) {
      throw new Error("PYTHON_BACKEND_URL is not configured");
    }
    const url = joinUrl(this.config.pythonBackendUrl, "/v1/agent/draft");
    const token = await this.idTokenProvider(this.config.audience);

    const message = truncate(req.message, this.config.maxMessageChars);
    const body = JSON.stringify({
      merchantId: req.merchantId,
      customerId: req.customerId,
      message,
      history: req.history ?? [],
    });

    const resp = await this.fetchImpl(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${token}`,
      },
      body,
    });

    if (!resp.ok) {
      const detail = await safeText(resp);
      throw new Error(`agent draft failed: HTTP ${resp.status} ${detail}`);
    }

    const payload = (await resp.json()) as DraftResponse;
    if (typeof payload?.draft !== "string") {
      throw new Error("agent draft response missing 'draft'");
    }
    return payload;
  }
}

// ---------------------------------------------------------------------------
// Helpers (exported for tests)
// ---------------------------------------------------------------------------

export function joinUrl(base: string, path: string): string {
  const b = base.endsWith("/") ? base.slice(0, -1) : base;
  const p = path.startsWith("/") ? path : `/${path}`;
  return `${b}${p}`;
}

export function truncate(s: string, maxChars: number): string {
  if (s.length <= maxChars) return s;
  return `${s.slice(0, maxChars - 1)}…`;
}

async function safeText(resp: {text(): Promise<string>}): Promise<string> {
  try {
    return (await resp.text()).slice(0, 200);
  } catch {
    return "";
  }
}

function defaultIdTokenProvider(): IdTokenProvider {
  // One GoogleAuth instance per process — its internal credential
  // cache short-circuits repeat calls.
  const auth = new GoogleAuth();
  const clientByAudience = new Map<string, Promise<IdTokenClient>>();

  return async (audience: string): Promise<string> => {
    let clientP = clientByAudience.get(audience);
    if (!clientP) {
      clientP = auth.getIdTokenClient(audience);
      clientByAudience.set(audience, clientP);
    }
    const client = await clientP;
    const headers = await client.getRequestHeaders();
    const auth_header = headers["Authorization"] ?? headers["authorization"] ?? "";
    const match = /^Bearer\s+(.+)$/i.exec(auth_header);
    if (!match) {
      throw new Error("failed to mint Google ID token");
    }
    return match[1];
  };
}
