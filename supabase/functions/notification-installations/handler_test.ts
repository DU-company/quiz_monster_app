import { createHandler, createRestRpc, type Rpc, RpcError } from "./handler.ts";
const secret = "a".repeat(64);
const id = "12345678-1234-4123-8123-123456789abc";
const registered = { revision: 0, enabled: false };
const base = { action: "register", installation_id: id };
const synced = {
  ...base,
  action: "sync",
  revision: 1,
  enabled: true,
  fcm_token: "token",
};
function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
const req = (body: unknown = base, headers: Record<string, string> = {}) =>
  new Request("https://example.test", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Installation-Secret": secret,
      ...headers,
    },
    body: JSON.stringify(body),
  });
function mock(result: unknown = registered) {
  const calls: { name: string; params: Record<string, unknown> }[] = [];
  const rpc: Rpc = async (name, params) => {
    calls.push({ name, params });
    return name === "notification_take_rate_limit" ? true : result;
  };
  return { calls, handler: createHandler(rpc) };
}
Deno.test("registration hashes credential and never returns private fields", async () => {
  const { calls, handler } = mock({
    ...registered,
    credential_hash: secret,
    fcm_token: "private",
  });
  const response = await handler(req());
  equal(response.status, 200);
  equal(await response.json(), registered);
  equal(calls.map((c) => c.name), [
    "notification_take_rate_limit",
    "notification_take_rate_limit",
    "notification_register",
  ]);
  equal(calls[0].params, {
    p_bucket: "global:register",
    p_limit: 30,
    p_window_seconds: 60,
  });
  equal(calls[1].params, {
    p_bucket: `installation:${id}`,
    p_limit: 60,
    p_window_seconds: 60,
  });
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(secret),
  );
  equal(
    calls[2].params.p_credential_hash,
    Array.from(new Uint8Array(digest), (v) => v.toString(16).padStart(2, "0"))
      .join(""),
  );
});
Deno.test("sync maps all fields including OFF without token", async () => {
  const { calls, handler } = mock({ ...registered, revision: 2 });
  const response = await handler(
    req({ ...synced, revision: 2, enabled: false, fcm_token: null }),
  );
  equal(response.status, 200);
  equal(calls[0].params.p_limit, 1000);
  equal(calls[2].name, "notification_sync");
  equal(calls[2].params.p_revision, 2);
  equal(calls[2].params.p_fcm_token, null);
  equal(calls[2].params.p_enabled, false);
});
Deno.test("invalid authentication stops before RPC", async () => {
  for (const value of ["", "abc", "a".repeat(63), "g".repeat(64)]) {
    const { handler, calls } = mock();
    equal(
      (await handler(req(base, { "X-Installation-Secret": value }))).status,
      401,
    );
    equal(calls.length, 0);
  }
});
Deno.test("invalid request fields stop before RPC", async () => {
  const invalid = [
    null,
    [],
    {},
    { ...base, installation_id: "invalid" },
    { ...synced, revision: 0 },
    { ...synced, revision: 1.5 },
    { ...synced, revision: Number.MAX_SAFE_INTEGER + 1 },
    { ...synced, enabled: "true" },
    { ...synced, fcm_token: null },
    { ...synced, fcm_token: "" },
    { ...synced, fcm_token: "  " },
    { ...synced, fcm_token: "a".repeat(4097) },
    { ...synced, fcm_token: undefined },
  ];
  for (const body of invalid) {
    const { handler, calls } = mock();
    equal((await handler(req(body))).status, 400);
    equal(calls.length, 0);
  }
});
Deno.test("actual streamed bytes are bounded even with false Content-Length", async () => {
  const { handler, calls } = mock();
  const bytes = new TextEncoder().encode(
    JSON.stringify({ ...base, padding: "a".repeat(9000) }),
  );
  const body = new ReadableStream({
    start(controller) {
      controller.enqueue(bytes.slice(0, 5000));
      controller.enqueue(bytes.slice(5000));
      controller.close();
    },
  });
  const response = await handler(
    new Request("https://example.test", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Installation-Secret": secret,
        "Content-Length": "1",
      },
      body,
    }),
  );
  equal(response.status, 400);
  equal(calls.length, 0);
});
Deno.test("method and media type validation", async () => {
  const { handler } = mock();
  equal((await handler(new Request("https://example.test"))).status, 405);
  equal(
    (await handler(req(base, { "Content-Type": "text/plain" }))).status,
    415,
  );
});
Deno.test("global and installation rate limiting are fail closed", async () => {
  for (const deniedAt of [1, 2]) {
    let calls = 0;
    const handler = createHandler(async () => ++calls !== deniedAt);
    equal((await handler(req())).status, 429);
    equal(calls, deniedAt);
  }
});
Deno.test("RPC errors map only known public errors", async () => {
  for (
    const [code, message, status, expected] of [
      ["PT401", "private credential", 401, "installation_auth_failed"],
      ["PT409", "revision_conflict", 409, "revision_conflict"],
      ["PT409", "token_conflict", 409, "token_conflict"],
      ["PT409", secret, 503, "temporarily_unavailable"],
      ["XX000", secret, 503, "temporarily_unavailable"],
    ] as const
  ) {
    const handler = createHandler(async (name) => {
      if (name === "notification_take_rate_limit") return true;
      throw new RpcError(code, message);
    });
    const response = await handler(req());
    equal(response.status, status);
    equal(await response.json(), { error: expected });
  }
});
Deno.test("malformed RPC success and network failures do not leak internals", async () => {
  const response = await mock({ secret }).handler(req());
  equal(response.status, 503);
  equal(await response.json(), { error: "temporarily_unavailable" });
  const failed = await createHandler(async () => {
    throw new Error(secret);
  })(req());
  equal(failed.status, 503);
  equal(await failed.json(), { error: "temporarily_unavailable" });
});
Deno.test("REST adapter authenticates service RPC and sets bounded timeout", async () => {
  const fetcher: typeof fetch = async (url, options) => {
    equal(url, "http://localhost/rest/v1/rpc/notification_register");
    equal(
      (options?.headers as Record<string, string>).Authorization,
      "Bearer test-service-key",
    );
    equal(options?.method, "POST");
    equal(!!options?.signal, true);
    return new Response(JSON.stringify(registered));
  };
  equal(
    await createRestRpc("http://localhost/", "test-service-key", fetcher)(
      "notification_register",
      {},
    ),
    registered,
  );
});
