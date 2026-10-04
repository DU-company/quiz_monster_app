import { createRestRpc } from "../functions/notification-installations/handler.ts";
import { createSendHandler } from "../functions/send-notification/handler.ts";

const url = Deno.env.get("NOTIFICATION_TEST_REST_URL");
const key = Deno.env.get("NOTIFICATION_TEST_SERVICE_KEY");
const database = Deno.env.get("NOTIFICATION_TEST_DB_NAME");
const container = Deno.env.get("NOTIFICATION_TEST_DB_CONTAINER");
function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
Deno.test({
  name:
    "isolated SQL + mock FCM: legacy and scheduled jobs, consent, rotation, retry and outage",
  ignore: !url || !key || !database || !container,
  fn: async () => {
    assert(
      new URL(url!).hostname === "127.0.0.1",
      "loopback PostgREST required",
    );
    assert(
      /^quiz_notifications_[a-z0-9_]+$/.test(database!),
      "disposable DB required",
    );
    async function sql(query: string) {
      const result = await new Deno.Command("docker", {
        args: [
          "exec",
          "-i",
          container!,
          "psql",
          "-U",
          "postgres",
          "-d",
          database!,
          "-v",
          "ON_ERROR_STOP=1",
          "-c",
          query,
        ],
        stdout: "piped",
        stderr: "piped",
      }).output();
      assert(result.success, "isolated SQL fixture update failed");
    }
    const rpc = createRestRpc(
      url!,
      key!,
      (input, init) =>
        fetch(String(input).replace(`${url}/rest/v1/`, `${url}/`), init),
    );
    const ids = Array.from({ length: 4 }, () => crypto.randomUUID());
    const tokens = ids.map((id) => `schedule-integration-${id}`);
    const legacy = crypto.randomUUID(),
      modern = crypto.randomUUID(),
      expired = crypto.randomUUID();
    const credential = "c".repeat(64), secret = "d".repeat(64);
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
    let retry = true;
    const calls: string[] = [];
    const handler = createSendHandler(rpc, (token) => {
      calls.push(token);
      return Promise.resolve(
        token === tokens[1] && retry
          ? { kind: "retry" as const, retryAfterSeconds: 60 }
          : { kind: "sent" as const },
      );
    }, secret);
    async function request(body: unknown) {
      const response = await handler(
        new Request("http://localhost/send-notification", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Notification-Key": secret,
          },
          body: JSON.stringify(body),
        }),
      );
      assert(response.status === 200, "handler response");
      return await response.json();
    }
    const future = new Date(Date.now() + 3 * 86400000).toISOString();
    await request({
      action: "schedule",
      job_id: modern,
      title: "일회성",
      body: "본문",
      installation_ids: ids,
      scheduled_at: future,
    });
    await request({ action: "process", job_id: modern, max_batches: 20 });
    assert(Number(calls.length) === 0, "future job never sent early");
    await request({
      action: "enqueue",
      job_id: legacy,
      title: "기존 정기",
      body: "본문",
      installation_ids: ids,
    });
    await rpc("notification_sync", {
      p_installation_id: ids[2],
      p_credential_hash: credential,
      p_revision: 2,
      p_enabled: false,
      p_fcm_token: null,
    });
    await rpc("notification_sync", {
      p_installation_id: ids[3],
      p_credential_hash: credential,
      p_revision: 2,
      p_enabled: true,
      p_fcm_token: `new-${tokens[3]}`,
    });
    await sql(
      `update public.push_jobs set scheduled_at=clock_timestamp()-interval '1 second',created_at=clock_timestamp()-interval '3 days' where id='${modern}';`,
    );
    await request({ action: "process", max_batches: 20 });
    await request({ action: "process", max_batches: 20 });
    assert(
      Number(calls.length) === 5,
      "both jobs processed only current consent/token snapshots",
    );
    assert(
      !calls.includes(tokens[2]) && !calls.includes(tokens[3]),
      "OFF and obsolete token excluded",
    );
    let oldStatus = await request({ action: "status", job_id: legacy });
    let newStatus = await request({ action: "status", job_id: modern });
    assert(
      oldStatus.counts.sent === 1 && oldStatus.counts.retry === 1 &&
        oldStatus.counts.skipped === 2,
      "legacy snapshot preserved",
    );
    assert(
      newStatus.counts.sent === 2 && newStatus.counts.retry === 1,
      "scheduled snapshot selected rotated token at due time",
    );
    await request({ action: "process", max_batches: 20 });
    assert(Number(calls.length) === 5, "retry delay enforced");
    retry = false;
    await sql(
      `update public.push_deliveries set available_at=clock_timestamp()-interval '1 second' where job_id in ('${legacy}','${modern}') and status='retry';`,
    );
    await request({ action: "process", max_batches: 20 });
    oldStatus = await request({ action: "status", job_id: legacy });
    newStatus = await request({ action: "status", job_id: modern });
    assert(
      oldStatus.counts.sent === 2 && newStatus.counts.sent === 3 &&
        Number(calls.length) === 7,
      "only retry recipients resumed",
    );
    await request({
      action: "schedule",
      job_id: expired,
      title: "중단",
      body: "본문",
      installation_ids: ids,
      scheduled_at: future,
    });
    await sql(
      `update public.push_jobs set scheduled_at=clock_timestamp()-interval '25 hours' where id='${expired}';`,
    );
    await request({ action: "process", job_id: expired, max_batches: 20 });
    const status = await request({ action: "status", job_id: expired });
    assert(
      status.state === "expired" && status.started_at === null &&
        Number(calls.length) === 7,
      "outage beyond deadline never sends stale message",
    );
  },
});
