import { createSendHandler, scheduledInstant } from "./handler.ts";
import { type Rpc, RpcError } from "../notification-installations/handler.ts";
import type { SendResult } from "./fcm.ts";

function assert(value: unknown, message = "Assertion failed"): asserts value {
  if (!value) throw new Error(message);
}
const secret = "a".repeat(64);
const job = "11111111-1111-4111-8111-111111111111";
const base = {
  action: "enqueue",
  job_id: job,
  title: "퀴즈",
  body: "함께해요",
  all: true,
};
function request(body: unknown) {
  return new Request("http://localhost/send-notification", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "X-Notification-Key": secret,
    },
    body: JSON.stringify(body),
  });
}
const sent = (): Promise<SendResult> => Promise.resolve({ kind: "sent" });
function claims(count = 5) {
  return Array.from({ length: count }, (_, index) => ({
    job_id: job,
    installation_id: `22222222-2222-4222-8222-${
      String(index).padStart(12, "0")
    }`,
    claim_id: `33333333-3333-4333-8333-${String(index).padStart(12, "0")}`,
    fcm_token: `synthetic-token-${index}`,
    title: "퀴즈",
    body: "함께해요",
  }));
}

Deno.test("schedule normalizes KST midnight and cross-year to UTC", async () => {
  const values = [
    ["2027-01-01T00:00:00+09:00", "2026-12-31T15:00:00.000Z"],
    ["2028-02-29T00:00:00.12+09:00", "2028-02-28T15:00:00.120Z"],
    ["2027-12-31T23:59:59-09:00", "2028-01-01T08:59:59.000Z"],
  ];
  for (const [input, expected] of values) {
    assert(scheduledInstant(input) === expected);
    const calls: [string, Record<string, unknown>][] = [];
    const rpc: Rpc = (name, params) => {
      calls.push([name, params]);
      return Promise.resolve({ job_id: job });
    };
    const response = await createSendHandler(rpc, null, secret)(
      request({ ...base, scheduled_at: input }),
    );
    assert(response.status === 200 && calls.length === 1);
    assert(calls[0][0] === "notification_schedule");
    assert(
      calls[0][1].p_scheduled_at === expected &&
        calls[0][1].p_source === "dashboard",
    );
  }
});

Deno.test("invalid calendar, zone and scheduling types never reach RPC", async () => {
  let called = false;
  const rpc: Rpc = () => {
    called = true;
    return Promise.resolve(null);
  };
  for (
    const scheduled_at of [
      "2027-02-29T00:00:00Z",
      "2028-02-30T00:00:00Z",
      "2027-13-01T00:00:00Z",
      "2027-01-00T00:00:00Z",
      "2027-01-01T24:00:00Z",
      "2027-01-01T00:60:00Z",
      "2027-01-01T00:00:60Z",
      "2027-01-01T00:00:00",
      "2027-01-01",
      "2027-01-01T00:00:00+14:01",
      "2027-01-01T00:00:00+15:00",
      "2027-01-01T00:00:00+09:60",
      "2027-01-01T00:00:00.1234Z",
      123,
      {},
      true,
    ]
  ) {
    const response = await createSendHandler(rpc, null, secret)(
      request({ ...base, scheduled_at }),
    );
    assert(response.status === 400, JSON.stringify(scheduled_at));
  }
  assert(!called);
});

Deno.test("multibyte message boundaries and source restrict scheduling contract", async () => {
  let calls = 0;
  const rpc: Rpc = () => {
    calls++;
    return Promise.resolve({ job_id: job });
  };
  const handler = createSendHandler(rpc, null, secret);
  assert(
    (await handler(
      request({
        ...base,
        source: "dashboard",
        title: "한".repeat(120),
        body: "한".repeat(1000),
      }),
    )).status === 200,
  );
  for (
    const override of [
      { title: "한".repeat(121) },
      { body: "한".repeat(1001) },
      { source: "cron" },
      { source: null },
    ]
  ) {
    assert((await handler(request({ ...base, ...override }))).status === 400);
  }
  assert(calls === 1);
});

Deno.test("legacy immediate enqueue and dashboard immediate null use separate compatible RPCs", async () => {
  for (
    const override of [{}, { source: "dashboard" }, { scheduled_at: null }]
  ) {
    const calls: [string, Record<string, unknown>][] = [];
    const rpc: Rpc = (name, params) => {
      calls.push([name, params]);
      return Promise.resolve({ job_id: job });
    };
    const response = await createSendHandler(rpc, null, secret)(
      request({ ...base, ...override }),
    );
    assert(response.status === 200 && calls.length === 1);
    const legacy = Object.keys(override).length === 0;
    assert(
      calls[0][0] ===
        (legacy ? "notification_enqueue" : "notification_schedule"),
    );
    assert(
      legacy
        ? !("p_scheduled_at" in calls[0][1])
        : calls[0][1].p_scheduled_at === null,
    );
  }
});

Deno.test("past timestamp reaches DB so existing job replay succeeds and new past job can reject", async () => {
  for (const replay of [true, false]) {
    let called = false;
    const rpc: Rpc = (name, params) => {
      called = true;
      assert(
        name === "notification_schedule" &&
          params.p_scheduled_at === "2020-01-01T00:00:00.000Z",
      );
      if (!replay) throw new RpcError("PT400", "past new schedule");
      return Promise.resolve({ job_id: job });
    };
    const response = await createSendHandler(rpc, null, secret)(
      request({ ...base, scheduled_at: "2020-01-01T00:00:00Z" }),
    );
    assert(called && response.status === (replay ? 200 : 400));
  }
});

Deno.test("worker max_batches rejects out-of-range and noninteger budgets before claim", async () => {
  let calls = 0;
  const rpc: Rpc = () => {
    calls++;
    return Promise.resolve([]);
  };
  for (const max_batches of [0, -1, 21, 100, 1.5, "20", true, {}]) {
    const response = await createSendHandler(rpc, sent, secret)(
      request({ action: "process", max_batches }),
    );
    assert(response.status === 400);
  }
  assert(calls === 0);
});

Deno.test("worker caps at 100 deliveries and five concurrently while honoring each allowed budget", async () => {
  for (
    const max_batches of [
      undefined,
      ...Array.from({ length: 20 }, (_, i) => i + 1),
    ]
  ) {
    let batches = 0, active = 0, peak = 0, sends = 0;
    const rpc: Rpc = (name, params) => {
      if (name === "notification_claim") {
        batches++;
        assert(params.p_limit === 5 && params.p_job_id === job && active === 0);
        return Promise.resolve(claims());
      }
      return Promise.resolve(true);
    };
    const sender = async (): Promise<SendResult> => {
      sends++;
      peak = Math.max(peak, ++active);
      await new Promise((resolve) => setTimeout(resolve, 0));
      active--;
      return { kind: "sent" };
    };
    const response = await createSendHandler(rpc, sender, secret, () => 0)(
      request({ action: "process", job_id: job, max_batches }),
    );
    const body = await response.json();
    assert(response.status === 200 && batches === (max_batches ?? 1));
    assert(sends === batches * 5 && sends <= 100 && peak === 5 && active === 0);
    assert(
      body.claimed === sends && body.recorded === sends &&
        body.unrecorded === 0,
    );
  }
});

Deno.test("fourth monotonic reading reaching deadline stops before next batch and preserves results", async () => {
  const times = [0, 10_000, 29_999, 30_000];
  let clockReads = 0, batches = 0;
  const rpc: Rpc = (name) => {
    if (name === "notification_claim") {
      batches++;
      return Promise.resolve(claims());
    }
    return Promise.resolve(true);
  };
  const response = await createSendHandler(
    rpc,
    sent,
    secret,
    () => times[clockReads++] ?? 30_000,
  )(request({ action: "process", max_batches: 20 }));
  const result = await response.json();
  assert(
    clockReads === 4 && batches === 3 && result.claimed === 15 &&
      result.recorded === 15,
  );
});

Deno.test("worker stops when queue empty after recording a partial batch", async () => {
  let batches = 0;
  const rpc: Rpc = (name) => {
    if (name === "notification_claim") {
      return Promise.resolve(++batches === 1 ? claims(2) : []);
    }
    return Promise.resolve(true);
  };
  const response = await createSendHandler(rpc, sent, secret, () => 0)(
    request({ action: "process", max_batches: 20 }),
  );
  assert(
    batches === 2 &&
      await response.text() === '{"claimed":2,"recorded":2,"unrecorded":0}',
  );
});

Deno.test("unrecorded partial batch halts further claims for false and failed finish", async () => {
  for (const throws of [false, true]) {
    let batches = 0, finishes = 0;
    const rpc: Rpc = (name) => {
      if (name === "notification_claim") {
        batches++;
        return Promise.resolve(claims());
      }
      if (name === "notification_delivery_current") {
        return Promise.resolve(true);
      }
      if (++finishes === 1) {
        if (throws) throw new Error("private upstream detail");
        return Promise.resolve(false);
      }
      return Promise.resolve(true);
    };
    const response = await createSendHandler(rpc, sent, secret, () => 0)(
      request({ action: "process", max_batches: 20 }),
    );
    assert(batches === 1 && finishes === 5);
    assert(
      await response.text() === '{"claimed":5,"recorded":4,"unrecorded":1}',
    );
  }
});
