import { createSendHandler } from "./handler.ts";
import { type Rpc, RpcError } from "../notification-installations/handler.ts";

function assert(value: unknown): asserts value {
  if (!value) throw new Error("Assertion failed");
}
const secret = "a".repeat(64);
function request(body: unknown, key = secret) {
  return new Request("http://localhost/send-notification", {
    method: "POST",
    headers: { "content-type": "application/json", "X-Notification-Key": key },
    body: JSON.stringify(body),
  });
}
Deno.test("list defaults and explicit pagination need no Firebase and never process", async () => {
  for (
    const [input, page, size] of [[{}, 1, 50], [
      { page: 2, page_size: 100 },
      2,
      100,
    ]] as const
  ) {
    const calls: unknown[] = [];
    const result = {
      jobs: [{ job_id: "test", state: "waiting" }],
      total: 101,
      page,
      page_size: size,
    };
    const rpc: Rpc = (name, args) => {
      calls.push(name);
      assert(name === "notification_list");
      assert(args.p_page === page && args.p_page_size === size);
      return Promise.resolve(result);
    };
    const response = await createSendHandler(rpc, null, secret)(
      request({ action: "list", ...input }),
    );
    assert(
      response.status === 200 &&
        response.headers.get("cache-control") === "no-store",
    );
    assert(JSON.stringify(await response.json()) === JSON.stringify(result));
    assert(calls.length === 1);
  }
});
Deno.test("list validates integer range and rejects explicit null without RPC", async () => {
  let called = false;
  const rpc: Rpc = () => {
    called = true;
    return Promise.resolve({});
  };
  for (const field of ["page", "page_size"]) {
    for (
      const value of [
        null,
        0,
        -1,
        1.1,
        "1",
        true,
        {},
        [],
        field === "page" ? 10001 : 101,
      ]
    ) {
      const response = await createSendHandler(rpc, null, secret)(
        request({ action: "list", [field]: value }),
      );
      assert(response.status === 400);
    }
  }
  assert(!called);
});
Deno.test("list requires caller key and suppresses backend error detail", async () => {
  let calls = 0;
  const rpc: Rpc = () => {
    calls++;
    throw new Error("private-key-value");
  };
  let response = await createSendHandler(rpc, null, secret)(
    request({ action: "list" }, "b".repeat(64)),
  );
  assert(response.status === 401 && calls === 0);
  response = await createSendHandler(rpc, null, secret)(
    request({ action: "list" }),
  );
  assert(response.status === 503);
  assert(!(await response.text()).includes("private-key-value"));
});
Deno.test("list maps DB validation errors without leaking database messages", async () => {
  const rpc: Rpc = () => {
    throw new RpcError("PT400", "private-db-details");
  };
  const response = await createSendHandler(rpc, null, secret)(
    request({ action: "list" }),
  );
  assert(
    response.status === 400 &&
      (await response.json()).error === "invalid_request",
  );
});

Deno.test("dedicated schedule action always uses modern RPC even for implicit immediate", async () => {
  const job = "11111111-1111-4111-8111-111111111111";
  for (
    const scheduling of [{}, { scheduled_at: null }, {
      scheduled_at: "2027-01-01T00:00:00+09:00",
    }]
  ) {
    let calls = 0;
    const rpc: Rpc = (name, args) => {
      calls++;
      assert(
        name === "notification_schedule" && args.p_source === "dashboard" &&
          args.p_job_id === job,
      );
      assert(
        args.p_scheduled_at ===
          (scheduling.scheduled_at ? "2026-12-31T15:00:00.000Z" : null),
      );
      return Promise.resolve({ job_id: job });
    };
    const response = await createSendHandler(rpc, null, secret)(
      request({
        action: "schedule",
        job_id: job,
        title: "title",
        body: "body",
        all: true,
        ...scheduling,
      }),
    );
    assert(response.status === 200 && calls === 1);
  }
});
Deno.test("dedicated schedule requires valid job id before any RPC", async () => {
  let called = false;
  const rpc: Rpc = () => {
    called = true;
    return Promise.resolve({});
  };
  for (const job_id of [undefined, null, "bad"]) {
    const response = await createSendHandler(rpc, null, secret)(
      request({
        action: "schedule",
        job_id,
        title: "title",
        body: "body",
        all: true,
      }),
    );
    assert(response.status === 400);
  }
  assert(!called);
});
