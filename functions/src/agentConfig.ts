// ============================================================
// Vanij — agent Cloud Function configuration.
//
// All secrets / URLs come from process.env populated by Secret Manager
// at deploy time. Never hardcode.
// ============================================================
export interface AgentConfig {
  /** Fully-qualified base URL of the FastAPI service on Cloud Run. */
  pythonBackendUrl: string;
  /** The `aud` value the Cloud Run identity token must carry. Always
   * equals `pythonBackendUrl` — callers don't need to set it separately. */
  audience: string;
  /** Feature flag: when false, onMessageCreated is a no-op. Useful for
   * rolling back agent behaviour without redeploying code. */
  enabled: boolean;
  /** Max characters of message body forwarded upstream (defence in
   * depth — FastAPI also caps via pydantic). */
  maxMessageChars: number;
}

export function loadAgentConfig(env: NodeJS.ProcessEnv = process.env): AgentConfig {
  const url = (env.PYTHON_BACKEND_URL ?? "").trim();
  const enabled = (env.AGENT_ENABLED ?? "true").toLowerCase() !== "false";
  const maxMessageChars = parseMaxChars(env.AGENT_MAX_MESSAGE_CHARS);
  return {
    pythonBackendUrl: url,
    audience: url,
    enabled,
    maxMessageChars,
  };
}

function parseMaxChars(raw: string | undefined): number {
  const fallback = 2000;
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(parsed, 4000);
}
