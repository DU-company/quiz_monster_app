import { createRestRpc } from "../functions/notification-installations/handler.ts";
import { createSendHandler } from "../functions/send-notification/handler.ts";

const url = Deno.env.get("NOTIFICATION_TEST_REST_URL");
const serviceKey = Deno.env.get("NOTIFICATION_TEST_SERVICE_KEY");
function assert(value: unknown, label: string): asserts value {
  if (!value) throw new Error(label);
}
Deno.test({
  name:
    "isolated PostgREST queue + handler: concurrent workers, partial failures, OFF and rotation",
  ignore: !url || !serviceKey,
  fn: async () => {
    // 격리 PostgREST는 Supabase 게이트웨이의 /rest/v1 접두사 없이 직접 실행한다.
    const rpc = createRestRpc(
      url!,
      serviceKey!,
      (input, init) =>
        fetch(String(input).replace(`${url}/rest/v1/`, `${url}/`), init),
    );
    const ids = Array.from({ length: 6 }, () => crypto.randomUUID());
    const job = crypto.randomUUID();
    const secret = "b".repeat(64);
    const credential = "a".repeat(64);
    const tokens = ids.map((id) => `test-only-${id}`);
    for (let i = 0; i < ids.length; i++) {
      await rpc("notification_register", {
        p_installation_id: ids[i],
        p_credential_hash: credential,
      });
      await rpc("notification_sync", {
        p_installation_id: ids[i],
        p_credential_hash: credential,
        p_revision: 1,
        p_enabled: true,
        p_fcm_token: tokens[i],
      });
    }
    const calls: string[] = [];
    const handler = createSendHandler(rpc, async (token) => {
      calls.push(token);
      if (token === tokens[1]) return { kind: "unregistered" };
      if (token === tokens[2]) return { kind: "retry", retryAfterSeconds: 120 };
      if (token === tokens[3]) throw new Error("ambiguous network failure");
      if (token === tokens[4]) {
        await rpc("notification_sync", {
          p_installation_id: ids[4],
          p_credential_hash: credential,
          p_revision: 2,
          p_enabled: true,
          p_fcm_token: `new-${tokens[4]}`,
        });
        return { kind: "unregistered" };
      }
      return { kind: "sent" };
    }, secret);
    const request = (body: unknown) =>
      handler(
        new Request("http://localhost/functions/v1/send-notification", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Notification-Key": secret,
          },
          body: JSON.stringify(body),
        }),
      );
    const enqueue = {
      action: "enqueue",
      job_id: job,
      title: "테스트",
      body: "격리 DB 검증",
      installation_ids: ids,
    };
    const enqueued = await Promise.all([request(enqueue), request(enqueue)]);
    for (const response of enqueued) {
      assert(response.status === 200, "concurrent enqueue idempotent");
    }
    assert(
      (await request({ ...enqueue, body: "다른 내용" })).status === 409,
      "changed content rejected",
    );
    await rpc("notification_sync", {
      p_installation_id: ids[5],
      p_credential_hash: credential,
      p_revision: 2,
      p_enabled: false,
      p_fcm_token: tokens[5],
    });
    await Promise.all([
      request({ action: "process", job_id: job }),
      request({ action: "process", job_id: job }),
    ]);
    await request({ action: "process", job_id: job });
    assert(
      calls.length === 5 && new Set(calls).size === 5,
      "each active recipient attempted once",
    );
    assert(!calls.includes(tokens[5]), "OFF excluded");
    const status = await (await request({ action: "status", job_id: job }))
      .json();
    assert(
      status.counts.sent === 1 && status.counts.invalid === 2 &&
        status.counts.retry === 1 && status.counts.unknown === 1 &&
        status.counts.skipped === 1,
      "partial outcomes persisted",
    );
    assert(status.remaining === 1, "only known retry remains");
    const active = await rpc("notification_active_tokens", {}) as {
      installation_id: string;
      fcm_token: string;
    }[];
    assert(
      !active.some((x) => x.installation_id === ids[1]),
      "unregistered token invalidated",
    );
    assert(
      active.some((x) =>
        x.installation_id === ids[4] && x.fcm_token === `new-${tokens[4]}`
      ),
      "late failure preserves new token",
    );
    assert(
      calls.length === 5,
      "retry does not bypass delay; unknown never resent",
    );
  },
});
