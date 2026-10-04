import { createFcmSender, type SendResult } from "./fcm.ts";
function assert(value: unknown, message = "Assertion failed"): asserts value {
  if (!value) throw new Error(message);
}
const keys = await crypto.subtle.generateKey(
  {
    name: "RSASSA-PKCS1-v1_5",
    modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]),
    hash: "SHA-256",
  },
  true,
  ["sign", "verify"],
);
const exported = new Uint8Array(
  await crypto.subtle.exportKey("pkcs8", keys.privateKey),
);
const account = {
  project_id: "test-project",
  client_email: "sender@test-project.iam.gserviceaccount.com",
  private_key: `-----BEGIN PRIVATE KEY-----\n${
    btoa(String.fromCharCode(...exported))
  }\n-----END PRIVATE KEY-----`,
};
const notification = { title: "퀴즈 몬스터", body: "함께 퀴즈를 즐겨요" };
const oauth = () =>
  Response.json({ access_token: "test-access", expires_in: 3600 });
function mock(
  handler: (url: string, init?: RequestInit) => Response | Promise<Response>,
): typeof fetch {
  return ((input: string | URL | Request, init?: RequestInit) =>
    Promise.resolve(handler(String(input), init))) as typeof fetch;
}

Deno.test("OAuth JWT uses verified RS256 signature, fixed audience/scope and sends notification", async () => {
  let requests = 0;
  const send = createFcmSender(
    account,
    mock(async (url, init) => {
      requests++;
      assert(init?.redirect === "error" && init.signal instanceof AbortSignal);
      if (url === "https://oauth2.googleapis.com/token") {
        const form = init.body as URLSearchParams;
        assert(
          form.get("grant_type") ===
            "urn:ietf:params:oauth:grant-type:jwt-bearer",
        );
        const parts = form.get("assertion")!.split(".");
        const decode = (part: string) =>
          Uint8Array.from(
            atob(part.replace(/-/g, "+").replace(/_/g, "/")),
            (char) => char.charCodeAt(0),
          );
        const claims = JSON.parse(new TextDecoder().decode(decode(parts[1])));
        assert(claims.iss === account.client_email && claims.aud === url);
        assert(
          claims.scope === "https://www.googleapis.com/auth/firebase.messaging",
        );
        assert(claims.iat === 1700000000 && claims.exp === 1700003600);
        assert(
          await crypto.subtle.verify(
            "RSASSA-PKCS1-v1_5",
            keys.publicKey,
            decode(parts[2]),
            new TextEncoder().encode(parts.slice(0, 2).join(".")),
          ),
        );
        return oauth();
      }
      assert(
        url ===
          "https://fcm.googleapis.com/v1/projects/test-project/messages:send",
      );
      assert(
        new Headers(init?.headers).get("authorization") ===
          "Bearer test-access",
      );
      const payload = JSON.parse(init!.body as string);
      assert(
        payload.message.token === "device" &&
          payload.message.notification.body === notification.body,
      );
      const apns = payload.message.apns;
      assert(apns.headers["apns-push-type"] === "alert");
      assert(apns.headers["apns-priority"] === "10");
      assert(apns.payload.aps.alert.title === notification.title);
      assert(apns.payload.aps.alert.body === notification.body);
      assert(
        apns.payload.aps.sound === "default",
        "iOS alerts request default sound",
      );
      assert(
        apns.payload.aps["interruption-level"] === "active",
        "normal alerts respect Focus and sound settings",
      );
      assert(
        !("content-available" in apns.payload.aps),
        "not a background-only push",
      );
      assert(!("android" in payload.message), "Android defaults unchanged");
      return Response.json({ name: "projects/test/messages/1" });
    }),
    () => 1700000000000,
  );
  assert((await send("device", notification)).kind === "sent");
  assert((await send("device", notification)).kind === "sent");
  assert(requests === 3);
});

Deno.test("concurrent requests share OAuth and renew near expiry", async () => {
  let now = 1700000000000;
  let refreshes = 0;
  const send = createFcmSender(
    account,
    mock((url) => {
      if (url.includes("oauth2")) {
        refreshes++;
        return oauth();
      }
      return Response.json({ name: "ok" });
    }),
    () => now,
  );
  await Promise.all([send("a", notification), send("b", notification)]);
  assert(refreshes === 1);
  now += 3541000;
  await send("a", notification);
  assert(Number(refreshes) === 2);
});

for (
  const [status, detail, kind] of [
    [404, "UNREGISTERED", "unregistered"],
    [404, "INVALID_ARGUMENT", "failed"],
    [400, "INVALID_ARGUMENT", "failed"],
    [403, "SENDER_ID_MISMATCH", "failed"],
    [401, "THIRD_PARTY_AUTH_ERROR", "failed"],
    [404, undefined, "failed"],
  ] as const
) {
  Deno.test(`FCM ${status} ${detail} classifies ${kind}`, async () => {
    const send = createFcmSender(
      account,
      mock((url) =>
        url.includes("oauth2") ? oauth() : Response.json({
          error: {
            details: detail
              ? [{
                "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
                errorCode: detail,
              }]
              : [],
          },
        }, { status })
      ),
    );
    assert((await send("device", notification)).kind === kind);
  });
}

Deno.test("untyped UNREGISTERED does not invalidate", async () => {
  const send = createFcmSender(
    account,
    mock((url) =>
      url.includes("oauth2") ? oauth() : Response.json(
        { error: { details: [{ errorCode: "UNREGISTERED" }] } },
        { status: 404 },
      )
    ),
  );
  assert((await send("device", notification)).kind === "failed");
});

for (
  const [status, header, delay] of [[429, "1", 60], [503, "120", 120], [
    500,
    "invalid",
    60,
  ], [503, "Tue, 14 Nov 2023 22:15:20 GMT", 120]] as const
) {
  Deno.test(`FCM ${status} respects Retry-After ${header}`, async () => {
    const send = createFcmSender(
      account,
      mock((url) =>
        url.includes("oauth2")
          ? oauth()
          : new Response(null, { status, headers: { "retry-after": header } })
      ),
      () => 1700000000000,
    );
    const result = await send("device", notification);
    assert(result.kind === "retry" && result.retryAfterSeconds === delay);
  });
}

Deno.test("FCM network ambiguity never retries", async () => {
  const send = createFcmSender(
    account,
    mock((url) => {
      if (url.includes("oauth2")) return oauth();
      throw new TypeError("connection lost");
    }),
  );
  assert((await send("device", notification)).kind === "unknown");
});

Deno.test("OAuth network failures can retry without sending FCM", async () => {
  let count = 0;
  const send = createFcmSender(
    account,
    mock(() => {
      count++;
      throw new TypeError("connection lost");
    }),
  );
  assert((await send("device", notification)).kind === "retry" && count === 1);
});

Deno.test("OAuth rejected credentials fail without sending FCM", async () => {
  let count = 0;
  const send = createFcmSender(
    account,
    mock(() => {
      count++;
      return Response.json({ error: "invalid_grant" }, { status: 400 });
    }),
  );
  assert((await send("device", notification)).kind === "failed" && count === 1);
});

Deno.test("malformed account fails without network", async () => {
  const send = createFcmSender(
    { ...account, private_key: "invalid" },
    mock(() => {
      throw new Error("must not fetch");
    }),
  );
  const result: SendResult = await send("device", notification);
  assert(result.kind === "failed");
});

Deno.test("FCM auth rejection expires cache without immediate resend", async () => {
  let refreshes = 0;
  let messages = 0;
  const send = createFcmSender(
    account,
    mock((url) => {
      if (url.includes("oauth2")) {
        refreshes++;
        return oauth();
      }
      messages++;
      return new Response(null, { status: 401 });
    }),
  );
  assert((await send("device", notification)).kind === "failed");
  assert(messages === 1 && refreshes === 1);
  await send("device", notification);
  assert(Number(messages) === 2 && Number(refreshes) === 2);
});

Deno.test("OAuth transient rejection respects Retry-After", async () => {
  const send = createFcmSender(
    account,
    mock(() =>
      new Response(null, { status: 503, headers: { "retry-after": "180" } })
    ),
  );
  const result = await send("device", notification);
  assert(result.kind === "retry" && result.retryAfterSeconds === 180);
});
