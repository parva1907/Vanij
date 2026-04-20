import * as assert from "assert";

import {AgentDraftClient, joinUrl, truncate} from "../src/agentDraft";
import type {FetchLike} from "../src/agentDraft";

function fakeFetch(responses: Array<Parameters<FetchLike>[1] & {status: number; body: unknown}>): FetchLike {
  const calls: Array<{url: string; init: Parameters<FetchLike>[1]}> = [];
  const fetcher: FetchLike = async (url, init) => {
    calls.push({url, init});
    const resp = responses.shift();
    if (!resp) throw new Error("no more fake responses queued");
    return {
      ok: resp.status >= 200 && resp.status < 300,
      status: resp.status,
      async text(): Promise<string> {
        return typeof resp.body === "string" ? resp.body : JSON.stringify(resp.body);
      },
      async json(): Promise<unknown> {
        return resp.body;
      },
    };
  };
  (fetcher as unknown as {calls: typeof calls}).calls = calls;
  return fetcher;
}

describe("agentDraft helpers", () => {
  it("joinUrl joins base + path, dedupes slashes", () => {
    assert.strictEqual(joinUrl("https://api/", "/v1/x"), "https://api/v1/x");
    assert.strictEqual(joinUrl("https://api", "v1/x"), "https://api/v1/x");
    assert.strictEqual(joinUrl("https://api", "/v1/x"), "https://api/v1/x");
  });

  it("truncate clips to max chars with ellipsis", () => {
    assert.strictEqual(truncate("hello", 10), "hello");
    const clipped = truncate("abcdefghij", 5);
    assert.strictEqual(clipped.length, 5);
    assert.ok(clipped.endsWith("…"));
  });
});

describe("AgentDraftClient.draft", () => {
  const config = {
    pythonBackendUrl: "https://backend.example.com",
    audience: "https://backend.example.com",
    enabled: true,
    maxMessageChars: 2000,
  } as const;

  it("posts to /v1/agent/draft with Bearer token + parsed response", async () => {
    const fetcher = fakeFetch([
      {
        status: 200,
        body: {
          draft: "hi — reviewed by merchant before sending.",
          model: "claude-test",
          latencyMs: 42,
          inventoryItemsUsed: 3,
        },
      } as never,
    ]);
    const client = new AgentDraftClient({
      config,
      fetchImpl: fetcher,
      idTokenProvider: async () => "ID-TOKEN",
    });

    const out = await client.draft({
      merchantId: "m1",
      customerId: "c1",
      message: "hello",
      history: [{sender: "customer", body: "yo"}],
    });

    assert.strictEqual(out.draft.includes("reviewed by merchant"), true);
    assert.strictEqual(out.model, "claude-test");
    assert.strictEqual(out.latencyMs, 42);
    assert.strictEqual(out.inventoryItemsUsed, 3);

    const calls = (fetcher as unknown as {calls: Array<{url: string; init: {headers: Record<string, string>; body: string}}>}).calls;
    assert.strictEqual(calls.length, 1);
    assert.strictEqual(calls[0].url, "https://backend.example.com/v1/agent/draft");
    assert.strictEqual(calls[0].init.headers["Authorization"], "Bearer ID-TOKEN");
    const posted = JSON.parse(calls[0].init.body);
    assert.strictEqual(posted.merchantId, "m1");
    assert.strictEqual(posted.customerId, "c1");
    assert.strictEqual(posted.message, "hello");
    assert.deepStrictEqual(posted.history, [{sender: "customer", body: "yo"}]);
  });

  it("throws on non-2xx", async () => {
    const fetcher = fakeFetch([{status: 503, body: "inventory unavailable"} as never]);
    const client = new AgentDraftClient({
      config,
      fetchImpl: fetcher,
      idTokenProvider: async () => "T",
    });
    await assert.rejects(
      () =>
        client.draft({
          merchantId: "m",
          customerId: "c",
          message: "hi",
        }),
      /HTTP 503/,
    );
  });

  it("refuses to call when PYTHON_BACKEND_URL is empty", async () => {
    const client = new AgentDraftClient({
      config: {...config, pythonBackendUrl: "", audience: ""},
      fetchImpl: fakeFetch([]),
      idTokenProvider: async () => "T",
    });
    await assert.rejects(
      () => client.draft({merchantId: "m", customerId: "c", message: "hi"}),
      /PYTHON_BACKEND_URL/,
    );
  });

  it("truncates oversize messages before POST", async () => {
    const fetcher = fakeFetch([
      {
        status: 200,
        body: {draft: "x", model: "m", latencyMs: 1, inventoryItemsUsed: 0},
      } as never,
    ]);
    const client = new AgentDraftClient({
      config: {...config, maxMessageChars: 10},
      fetchImpl: fetcher,
      idTokenProvider: async () => "T",
    });
    await client.draft({
      merchantId: "m",
      customerId: "c",
      message: "this is way too long for the config",
    });
    const calls = (fetcher as unknown as {calls: Array<{init: {body: string}}>}).calls;
    const posted = JSON.parse(calls[0].init.body);
    assert.strictEqual(posted.message.length, 10);
  });
});
