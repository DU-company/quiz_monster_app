import { runRequest } from "./notification-request.ts";
function assert(value: unknown): asserts value {
  if (!value) throw new Error("Assertion failed");
}
const secret = "a".repeat(64);
const payload = {
  action: "status",
  job_id: "11111111-1111-4111-8111-111111111111",
};
const env = (
  url = "https://example.supabase.co/functions/v1/send-notification",
  key = secret,
) =>
(name: string) =>
  name === "NOTIFICATION_API_URL"
    ? url
    : name === "NOTIFICATION_SEND_KEY"
    ? key
    : undefined;
const read = () => Promise.resolve(JSON.stringify(payload));
function fetchMock(
  fn: (input: string | URL | Request, init?: RequestInit) => Response,
): typeof fetch {
  return ((input: string | URL | Request, init?: RequestInit) =>
    Promise.resolve(fn(input, init))) as typeof fetch;
}
async function rejects(run: () => Promise<unknown>): Promise<Error> {
  try {
    await run();
  } catch (error) {
    assert(error instanceof Error);
    return error;
  }
  throw new Error("Expected rejection");
}
Deno.test("manual request uses server header and JSON file without query secret", async () => {
  let calls = 0;
  const result = await runRequest(
    ["request.json"],
    env(),
    (path) => {
      assert(path === "request.json");
      return read();
    },
    fetchMock((input, init) => {
      calls++;
      assert(
        String(input) ===
          "https://example.supabase.co/functions/v1/send-notification",
      );
      assert(
        init?.method === "POST" && init.redirect === "error" &&
          init.signal instanceof AbortSignal,
      );
      assert(new Headers(init.headers).get("X-Notification-Key") === secret);
      assert(
        new Headers(init.headers).get("Content-Type") === "application/json",
      );
      assert(init.body === JSON.stringify(payload));
      return Response.json({ sent: 1 });
    }),
  );
  assert(result.sent === 1 && calls === 1);
});
Deno.test("rejects non-HTTPS nonloopback and URL credentials/query/fragment before file read", async () => {
  for (
    const url of [
      "http://example.com",
      "ftp://example.com",
      "https://user:password@example.com",
      "https://example.com?key=private",
      "https://example.com#private",
      "http://localhost.example.com",
    ]
  ) {
    let reads = 0;
    await rejects(() =>
      runRequest(
        ["request.json"],
        env(url),
        () => {
          reads++;
          return read();
        },
        fetchMock(() => {
          throw new Error("must not fetch");
        }),
      )
    );
    assert(reads === 0);
  }
});
Deno.test("HTTP is permitted only for loopback test endpoints", async () => {
  for (
    const url of ["http://localhost:54321/send", "http://127.0.0.1:54321/send"]
  ) {
    assert(
      (await runRequest(
        ["request.json"],
        env(url),
        read,
        fetchMock(() => Response.json({ ok: true })),
      )).ok,
    );
  }
});
Deno.test("missing arguments or malformed server key reject without requests", async () => {
  for (
    const [args, key] of [[[], secret], [["a", "b"], secret], [
      ["a"],
      "bad",
    ]] as [string[], string][]
  ) {
    await rejects(() =>
      runRequest(
        args,
        env(undefined, key),
        read,
        fetchMock(() => {
          throw new Error("must not fetch");
        }),
      )
    );
  }
});
Deno.test("malformed action cannot reach server", async () => {
  let calls = 0;
  for (
    const value of [null, {}, [], { action: ["process"] }, { action: "delete" }]
  ) {
    await rejects(() =>
      runRequest(
        ["a"],
        env(),
        () => Promise.resolve(JSON.stringify(value)),
        fetchMock(() => {
          calls++;
          return Response.json({});
        }),
      )
    );
  }
  assert(calls === 0);
});
Deno.test("HTTP errors suppress upstream response body", async () => {
  const error = await rejects(() =>
    runRequest(
      ["a"],
      env(),
      read,
      fetchMock(() =>
        new Response("private-token private-key", { status: 503 })
      ),
    )
  );
  assert(error.message.includes("503") && !error.message.includes("private"));
});
