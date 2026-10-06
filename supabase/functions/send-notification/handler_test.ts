import { createSendHandler } from "./handler.ts";
import { type Rpc, RpcError } from "../notification-installations/handler.ts";
import type { SendResult } from "./fcm.ts";
function assert(value: unknown): asserts value {
  if (!value) throw new Error("Assertion failed");
}
const secret = "a".repeat(64);
const job = "11111111-1111-4111-8111-111111111111";
const install = "22222222-2222-4222-8222-222222222222";
const claim = {
  job_id: job,
  installation_id: install,
  claim_id: "33333333-3333-4333-8333-333333333333",
  fcm_token: "private-device-token",
  title: "퀴즈",
  body: "같이 즐겨요",
};
function request(body: unknown, key: string | null = secret) {
  return new Request("http://localhost/send-notification", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(key === null ? {} : { "X-Notification-Key": key }),
    },
    body: JSON.stringify(body),
  });
}
const forbidden: Rpc = () => {
  throw new Error("RPC must not be called");
};
const sent = (): Promise<SendResult> => Promise.resolve({ kind: "sent" });

Deno.test("missing and invalid configured key fail closed", async () => {
  for (const key of ["", "invalid", "A".repeat(64)]) {
    const response = await createSendHandler(forbidden, sent, key)(
      request({ action: "process" }),
    );
    assert(
      response.status === 503 &&
        (await response.json()).error === "sender_not_configured",
    );
  }
});
Deno.test("missing and wrong caller keys reject before body and RPC", async () => {
  for (const key of [null, "b".repeat(64), "a"]) {
    const response = await createSendHandler(forbidden, sent, secret)(
      request({ action: "process" }, key),
    );
    assert(
      response.status === 401 &&
        (await response.json()).error === "unauthorized",
    );
  }
});
Deno.test("only POST allowed", async () => {
  const response = await createSendHandler(forbidden, sent, secret)(
    new Request("http://localhost"),
  );
  assert(response.status === 405);
});
Deno.test("actual streamed size enforces limit despite forged content length", async () => {
  let canceled = false;
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(new Uint8Array(16385));
    },
    cancel() {
      canceled = true;
    },
  });
  const req = new Request("http://localhost", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "content-length": "1",
      "X-Notification-Key": secret,
    },
    body: stream,
  });
  const response = await createSendHandler(forbidden, sent, secret)(req);
  assert(response.status === 400 && canceled);
});
Deno.test("invalid JSON and content type rejected", async () => {
  for (
    const [type, body] of [["text/plain", "{}"], ["application/json", "{"], [
      "application/json",
      "[]",
    ], ["application/json", "null"]]
  ) {
    const response = await createSendHandler(forbidden, sent, secret)(
      new Request("http://localhost", {
        method: "POST",
        headers: { "content-type": type, "X-Notification-Key": secret },
        body,
      }),
    );
    assert(response.status === 400);
  }
});
Deno.test("actions, IDs and explicit audiences validated", async () => {
  const base = { action: "enqueue", job_id: job, title: "제목", body: "내용" };
  for (
    const body of [
      {},
      { action: "other" },
      { action: ["process"], job_id: job },
      { action: ["enqueue"], job_id: job },
      { action: "status" },
      { action: "process", job_id: "bad" },
      base,
      { ...base, all: false },
      { ...base, all: "true", installation_ids: [install] },
      { ...base, all: true, installation_ids: [install] },
      { ...base, installation_ids: [] },
      { ...base, installation_ids: ["bad"] },
      { ...base, installation_ids: Array(101).fill(install) },
      { ...base, all: true, title: " " },
      { ...base, all: true, body: "x".repeat(1001) },
      { ...base, all: true, title: "x".repeat(121) },
    ]
  ) {
    const response = await createSendHandler(forbidden, sent, secret)(
      request(body),
    );
    assert(response.status === 400);
  }
});
Deno.test("enqueue maps targeted and all audiences without Firebase configured", async () => {
  for (const all of [true, false]) {
    let calls = 0;
    const rpc: Rpc = (name, params) => {
      calls++;
      assert(
        name === "notification_enqueue" && params.p_job_id === job &&
          params.p_title === "제목" && params.p_body === "내용",
      );
      assert(
        all
          ? params.p_target_ids === null
          : JSON.stringify(params.p_target_ids) === JSON.stringify([install]),
      );
      return Promise.resolve({ job_id: job, recipients: 1 });
    };
    const response = await createSendHandler(rpc, null, secret)(
      request({
        action: "enqueue",
        job_id: job,
        title: "제목",
        body: "내용",
        ...(all ? { all: true } : { installation_ids: [install] }),
      }),
    );
    assert(
      response.status === 200 && (await response.json()).recipients === 1 &&
        calls === 1,
    );
  }
});
Deno.test("status uses job ID and no sender", async () => {
  const rpc: Rpc = (name, params) => {
    assert(name === "notification_job_status" && params.p_job_id === job);
    return Promise.resolve({ sent: 2 });
  };
  const response = await createSendHandler(rpc, null, secret)(
    request({ action: "status", job_id: job }),
  );
  assert(response.status === 200 && (await response.json()).sent === 2);
});
Deno.test("process requires Firebase config before claim", async () => {
  const response = await createSendHandler(forbidden, null, secret)(
    request({ action: "process" }),
  );
  assert(
    response.status === 503 &&
      (await response.json()).error === "firebase_not_configured",
  );
});
Deno.test("process claims at most five and supports optional job", async () => {
  for (const id of [job, undefined]) {
    const rpc: Rpc = (name, params) => {
      assert(
        name === "notification_claim" && params.p_limit === 5 &&
          params.p_job_id === (id ?? null),
      );
      return Promise.resolve([]);
    };
    const response = await createSendHandler(rpc, sent, secret)(
      request({ action: "process", job_id: id }),
    );
    assert(response.status === 200 && (await response.json()).claimed === 0);
  }
  const response = await createSendHandler(
    () => Promise.resolve(Array(6).fill(claim)),
    sent,
    secret,
  )(request({ action: "process" }));
  assert(response.status === 503);
});
Deno.test("pre-send OFF skips sender and records skipped", async () => {
  const rpc: Rpc = (name, params) => {
    if (name === "notification_claim") return Promise.resolve([claim]);
    assert(
      params.p_claim_id === claim.claim_id &&
        params.p_installation_id === install && params.p_job_id === job,
    );
    if (name === "notification_delivery_current") return Promise.resolve(false);
    assert(name === "notification_finish" && params.p_outcome === "skipped");
    return Promise.resolve(true);
  };
  const response = await createSendHandler(rpc, () => {
    throw new Error("must not send");
  }, secret)(request({ action: "process" }));
  assert((await response.json()).recorded === 1);
});
for (
  const [result, outcome, delay] of [
    [{ kind: "sent" }, "sent", 60],
    [{ kind: "unregistered" }, "invalid", 60],
    [{ kind: "failed" }, "failed", 60],
    [{ kind: "unknown" }, "unknown", 60],
    [{ kind: "retry", retryAfterSeconds: 1 }, "retry", 60],
    [{ kind: "retry", retryAfterSeconds: 60.5 }, "retry", 61],
    [{ kind: "retry", retryAfterSeconds: 86401 }, "failed", 86400],
    [{ kind: "retry", retryAfterSeconds: NaN }, "failed", 60],
  ] as [SendResult, string, number][]
) {
  Deno.test(`sender ${result.kind} maps outcome ${outcome} and delay ${delay}`, async () => {
    const rpc: Rpc = (name, params) => {
      if (name === "notification_claim") return Promise.resolve([claim]);
      if (name === "notification_delivery_current") {
        return Promise.resolve(true);
      }
      assert(params.p_outcome === outcome && params.p_retry_seconds === delay);
      return Promise.resolve(true);
    };
    const response = await createSendHandler(rpc, (token, message) => {
      assert(token === claim.fcm_token && message.body === claim.body);
      return Promise.resolve(result);
    }, secret)(request({ action: "process" }));
    assert((await response.json()).recorded === 1);
  });
}
Deno.test("sender exceptions become unknown once with no auto resend", async () => {
  let sends = 0;
  const rpc: Rpc = (name, params) => {
    if (name === "notification_claim") return Promise.resolve([claim]);
    if (name === "notification_delivery_current") return Promise.resolve(true);
    assert(params.p_outcome === "unknown");
    return Promise.resolve(true);
  };
  const response = await createSendHandler(rpc, () => {
    sends++;
    throw new Error("sensitive-token");
  }, secret)(request({ action: "process" }));
  assert((await response.json()).recorded === 1 && sends === 1);
});
Deno.test("partial finish errors report aggregate counts and no tokens", async () => {
  let finishes = 0;
  const rpc: Rpc = (name) => {
    if (name === "notification_claim") {
      return Promise.resolve([claim, { ...claim, installation_id: job }]);
    }
    if (name === "notification_delivery_current") return Promise.resolve(true);
    if (++finishes === 1) throw new Error("sensitive database body");
    return Promise.resolve(true);
  };
  const response = await createSendHandler(rpc, sent, secret)(
    request({ action: "process" }),
  );
  assert(
    response.status === 200 &&
      await response.text() === '{"claimed":2,"recorded":1,"unrecorded":1}',
  );
});
for (
  const [code, status, error] of [
    ["PT400", 400, "invalid_request"],
    ["PT404", 404, "job_not_found"],
    ["PT409", 409, "request_conflict"],
    ["XX000", 503, "temporarily_unavailable"],
  ] as const
) {
  Deno.test(`RPC ${code} hides upstream detail`, async () => {
    const response = await createSendHandler(
      () => {
        throw new RpcError(code, "private credentials");
      },
      sent,
      secret,
    )(request({ action: "status", job_id: job }));
    assert(
      response.status === status &&
        await response.text() === JSON.stringify({ error }),
    );
    assert(response.headers.get("cache-control") === "no-store");
  });
}
