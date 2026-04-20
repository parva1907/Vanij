import * as assert from "assert";

import {handleCustomerMessageCreated} from "../src/agentTrigger";
import type {AgentDraftClient} from "../src/agentDraft";

// ---------------------------------------------------------------------------
// Minimal Firestore stubs — enough surface for the trigger to exercise
// .collection/.doc/.where/.orderBy/.limit/.get/.set/.update.
// ---------------------------------------------------------------------------

interface FakeDoc {
  id: string;
  data: Record<string, unknown>;
}

class FakeQuery {
  constructor(
    private readonly store: FakeMessagesRef,
    private readonly filters: Array<[string, string, unknown]> = [],
    private readonly ordering: Array<[string, "asc" | "desc"]> = [],
    private readonly lim: number = 100,
  ) {}
  where(f: string, op: string, v: unknown): FakeQuery {
    return new FakeQuery(this.store, [...this.filters, [f, op, v]], this.ordering, this.lim);
  }
  orderBy(f: string, dir: "asc" | "desc" = "asc"): FakeQuery {
    return new FakeQuery(this.store, this.filters, [...this.ordering, [f, dir]], this.lim);
  }
  limit(n: number): FakeQuery {
    return new FakeQuery(this.store, this.filters, this.ordering, n);
  }
  async get(): Promise<{empty: boolean; docs: Array<{id: string; data(): Record<string, unknown>}>}> {
    let rows = [...this.store.docs];
    for (const [field, op, val] of this.filters) {
      if (op === "==") rows = rows.filter((d) => d.data[field] === val);
    }
    for (const [field, dir] of [...this.ordering].reverse()) {
      rows.sort((a, b) => {
        const av = a.data[field] as number;
        const bv = b.data[field] as number;
        return dir === "desc" ? bv - av : av - bv;
      });
    }
    rows = rows.slice(0, this.lim);
    return {
      empty: rows.length === 0,
      docs: rows.map((d) => ({id: d.id, data: () => d.data})),
    };
  }
}

class FakeDocRef {
  constructor(public readonly parent: FakeMessagesRef, public readonly id: string) {}
  async set(data: Record<string, unknown>): Promise<void> {
    this.parent.docs.push({id: this.id, data: {...data}});
  }
  async update(patch: Record<string, unknown>): Promise<void> {
    const existing = this.parent.docs.find((d) => d.id === this.id);
    if (existing) Object.assign(existing.data, patch);
  }
}

class FakeMessagesRef {
  public docs: FakeDoc[] = [];
  private counter = 0;
  doc(id?: string): FakeDocRef {
    if (id) return new FakeDocRef(this, id);
    this.counter += 1;
    return new FakeDocRef(this, `auto-${this.counter}`);
  }
  where(f: string, op: string, v: unknown): FakeQuery {
    return new FakeQuery(this).where(f, op, v);
  }
  orderBy(f: string, dir: "asc" | "desc" = "asc"): FakeQuery {
    return new FakeQuery(this).orderBy(f, dir);
  }
  limit(n: number): FakeQuery {
    return new FakeQuery(this).limit(n);
  }
}

class FakeCustomerRef {
  public updates: Record<string, unknown>[] = [];
  constructor(public readonly messagesRef: FakeMessagesRef) {}
  collection(name: string): FakeMessagesRef {
    assert.strictEqual(name, "messages");
    return this.messagesRef;
  }
  async update(patch: Record<string, unknown>): Promise<void> {
    this.updates.push(patch);
  }
}

class FakeCustomersCollection {
  constructor(public readonly customer: FakeCustomerRef) {}
  doc(_id: string): FakeCustomerRef {
    return this.customer;
  }
}

class FakeMerchantRef {
  constructor(public readonly customers: FakeCustomersCollection) {}
  collection(name: string): FakeCustomersCollection {
    assert.strictEqual(name, "customers");
    return this.customers;
  }
}

class FakeMerchantsCollection {
  constructor(public readonly merchant: FakeMerchantRef) {}
  doc(_id: string): FakeMerchantRef {
    return this.merchant;
  }
}

class FakeFirestore {
  public readonly customer: FakeCustomerRef;
  public readonly merchant: FakeMerchantRef;
  public readonly messages: FakeMessagesRef;
  constructor() {
    this.messages = new FakeMessagesRef();
    this.customer = new FakeCustomerRef(this.messages);
    this.merchant = new FakeMerchantRef(new FakeCustomersCollection(this.customer));
  }
  collection(name: string): FakeMerchantsCollection {
    assert.strictEqual(name, "merchants");
    return new FakeMerchantsCollection(this.merchant);
  }
}

function fakeClient(
  draftText: string,
  opts?: {shouldThrow?: boolean},
): AgentDraftClient {
  const calls: Array<Record<string, unknown>> = [];
  const client = {
    async draft(req: Record<string, unknown>) {
      calls.push(req);
      if (opts?.shouldThrow) throw new Error("llm down");
      return {
        draft: draftText,
        model: "claude-test",
        latencyMs: 10,
        inventoryItemsUsed: 2,
      };
    },
  } as unknown as AgentDraftClient;
  (client as unknown as {calls: typeof calls}).calls = calls;
  return client;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("handleCustomerMessageCreated", () => {
  it("skips non-customer senders", async () => {
    const fs = new FakeFirestore() as unknown as import("firebase-admin/firestore").Firestore;
    const client = fakeClient("x");
    const out = await handleCustomerMessageCreated(
      {firestore: fs, client},
      {merchantId: "m", customerId: "c", messageId: "msg1"},
      {sender: "merchant", body: "hi"},
    );
    assert.strictEqual(out, "skipped");
  });

  it("skips empty bodies", async () => {
    const fs = new FakeFirestore() as unknown as import("firebase-admin/firestore").Firestore;
    const client = fakeClient("x");
    const out = await handleCustomerMessageCreated(
      {firestore: fs, client},
      {merchantId: "m", customerId: "c", messageId: "msg1"},
      {sender: "customer", body: "   "},
    );
    assert.strictEqual(out, "skipped");
  });

  it("drafts a reply, marks it sender=agent + isDraft, and bumps customer timestamps", async () => {
    const rawFs = new FakeFirestore();
    const fs = rawFs as unknown as import("firebase-admin/firestore").Firestore;
    const client = fakeClient("there you go — reviewed by merchant before sending.");

    const out = await handleCustomerMessageCreated(
      {firestore: fs, client},
      {merchantId: "m", customerId: "c", messageId: "msg1"},
      {sender: "customer", body: "kya red saree hai?"},
    );

    assert.strictEqual(out, "drafted");
    assert.strictEqual(rawFs.messages.docs.length, 1);
    const written = rawFs.messages.docs[0].data;
    assert.strictEqual(written.sender, "agent");
    assert.strictEqual(written.isDraft, true);
    assert.strictEqual(written.agentDraftFromMessageId, "msg1");
    assert.ok(String(written.body).includes("reviewed by merchant"));
    assert.strictEqual(rawFs.customer.updates.length, 1);
  });

  it("is idempotent — no second draft for the same source message", async () => {
    const rawFs = new FakeFirestore();
    const fs = rawFs as unknown as import("firebase-admin/firestore").Firestore;
    // Seed an existing draft referencing msg1.
    rawFs.messages.docs.push({
      id: "preexisting",
      data: {
        sender: "agent",
        body: "already drafted",
        agentDraftFromMessageId: "msg1",
      },
    });

    const client = fakeClient("should not run");
    const out = await handleCustomerMessageCreated(
      {firestore: fs, client},
      {merchantId: "m", customerId: "c", messageId: "msg1"},
      {sender: "customer", body: "hi"},
    );

    assert.strictEqual(out, "skipped");
    assert.strictEqual(
      (client as unknown as {calls: unknown[]}).calls.length,
      0,
      "LLM must not be invoked on idempotent retry",
    );
  });

  it("swallows LLM errors (no retry storm on Firestore)", async () => {
    const rawFs = new FakeFirestore();
    const fs = rawFs as unknown as import("firebase-admin/firestore").Firestore;
    const client = fakeClient("x", {shouldThrow: true});
    const out = await handleCustomerMessageCreated(
      {firestore: fs, client},
      {merchantId: "m", customerId: "c", messageId: "msg1"},
      {sender: "customer", body: "hi"},
    );
    assert.strictEqual(out, "skipped");
    assert.strictEqual(rawFs.messages.docs.length, 0);
  });

  it("forwards recent history (oldest first), excluding the triggering message", async () => {
    const rawFs = new FakeFirestore();
    const fs = rawFs as unknown as import("firebase-admin/firestore").Firestore;
    rawFs.messages.docs.push(
      {id: "old1", data: {sender: "customer", body: "hi", createdAt: 1}},
      {id: "old2", data: {sender: "merchant", body: "namaste", createdAt: 2}},
      {id: "msg1", data: {sender: "customer", body: "kya red saree?", createdAt: 3}},
    );
    const client = fakeClient("ok — reviewed by merchant before sending.");

    await handleCustomerMessageCreated(
      {firestore: fs, client},
      {merchantId: "m", customerId: "c", messageId: "msg1"},
      {sender: "customer", body: "kya red saree?"},
    );

    const calls = (client as unknown as {calls: Array<{history: Array<{sender: string; body: string}>}>}).calls;
    assert.strictEqual(calls.length, 1);
    const {history} = calls[0];
    assert.deepStrictEqual(
      history.map((h) => h.sender),
      ["customer", "merchant"],
    );
    assert.strictEqual(history.find((h) => h.body === "kya red saree?"), undefined);
  });
});
