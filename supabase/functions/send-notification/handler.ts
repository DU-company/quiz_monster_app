import { type Rpc, RpcError } from "../notification-installations/handler.ts";
import type { SendResult } from "./fcm.ts";

type Sender = (
  token: string,
  message: { title: string; body: string },
) => Promise<SendResult>;
type Claim = {
  job_id: string;
  installation_id: string;
  claim_id: string;
  fcm_token: string;
  title: string;
  body: string;
};
const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
const validId = (value: unknown): value is string =>
  typeof value === "string" && uuid.test(value);
const respond = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
class InvalidRequest extends Error {}
// 타임존 없는 값과 JS Date가 보정하는 잘못된 날짜를 거부한다.
export function scheduledInstant(value: unknown): string {
  if (typeof value !== "string") throw new InvalidRequest();
  const m =
    /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?(Z|[+-]\d{2}:\d{2})$/
      .exec(value);
  if (!m) throw new InvalidRequest();
  const [year, month, day, hour, minute, second] = m.slice(1, 7).map(Number);
  const date = new Date(Date.UTC(year, month - 1, day, hour, minute, second));
  const offset = m[8];
  if (
    year < 1000 || date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day || hour > 23 || minute > 59 || second > 59 ||
    (offset !== "Z" &&
      (Number(offset.slice(1, 3)) > 14 || Number(offset.slice(4)) > 59 ||
        (Number(offset.slice(1, 3)) === 14 && Number(offset.slice(4)) !== 0)))
  ) {
    throw new InvalidRequest();
  }
  const time = Date.parse(value);
  if (!Number.isFinite(time)) throw new InvalidRequest();
  return new Date(time).toISOString();
}
async function bodyOf(request: Request): Promise<Record<string, unknown>> {
  if (
    request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !==
      "application/json" || !request.body
  ) throw new InvalidRequest();
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.length;
      if (length > 16384) {
        await reader.cancel();
        throw new InvalidRequest();
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  try {
    const value = JSON.parse(
      new TextDecoder("utf-8", { fatal: true }).decode(bytes),
    );
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      throw new Error();
    }
    return value;
  } catch {
    throw new InvalidRequest();
  }
}
async function authorized(request: Request, secret: string): Promise<boolean> {
  const supplied = request.headers.get("X-Notification-Key") ?? "";
  if (!/^[a-f0-9]{64}$/.test(supplied)) return false;
  // 동일 길이의 해시 전체를 비교해 첫 불일치 위치가 응답 시간에 드러나지 않게 한다.
  const hash = async (value: string) =>
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
    );
  const [a, b] = await Promise.all([hash(supplied), hash(secret)]);
  let mismatch = 0;
  for (let i = 0; i < a.length; i++) mismatch |= a[i] ^ b[i];
  return mismatch === 0;
}
export function createSendHandler(
  rpc: Rpc,
  send: Sender | null,
  secret: string,
  monotonicNow: () => number = () => performance.now(),
) {
  return async (request: Request): Promise<Response> => {
    if (!/^[a-f0-9]{64}$/.test(secret)) {
      return respond(503, { error: "sender_not_configured" });
    }
    if (request.method !== "POST") {
      return respond(405, { error: "method_not_allowed" });
    }
    if (!await authorized(request, secret)) {
      return respond(401, { error: "unauthorized" });
    }
    try {
      const body = await bodyOf(request);
      const { action, job_id } = body;
      if (
        typeof action !== "string" ||
        !["enqueue", "schedule", "process", "status", "list"].includes(
          action,
        ) ||
        (job_id !== undefined && !validId(job_id)) ||
        ((action === "enqueue" || action === "schedule" ||
          action === "status") && !validId(job_id))
      ) throw new InvalidRequest();
      if (action === "list") {
        const page = body.page === undefined ? 1 : body.page;
        const pageSize = body.page_size === undefined ? 50 : body.page_size;
        if (
          !Number.isInteger(page) || (page as number) < 1 ||
          (page as number) > 10000 ||
          !Number.isInteger(pageSize) || (pageSize as number) < 1 ||
          (pageSize as number) > 100
        ) {
          throw new InvalidRequest();
        }
        return respond(
          200,
          await rpc("notification_list", {
            p_page: page,
            p_page_size: pageSize,
          }),
        );
      }
      if (action === "enqueue" || action === "schedule") {
        const {
          title,
          body: message,
          installation_ids,
          all,
          source,
          scheduled_at,
        } = body;
        if (
          (all !== undefined && typeof all !== "boolean") ||
          typeof title !== "string" || !title.trim() || title.length > 120 ||
          typeof message !== "string" || !message.trim() ||
          message.length > 1000 ||
          new TextEncoder().encode(title).length > 480 ||
          new TextEncoder().encode(message).length > 3000 ||
          (source !== undefined && source !== "dashboard") ||
          (all === true
            ? installation_ids !== undefined
            : !Array.isArray(installation_ids) || installation_ids.length < 1 ||
              installation_ids.length > 100 || !installation_ids.every(validId))
        ) throw new InvalidRequest();
        // 날짜의 과거 여부는 DB가 새 작업에만 검사한다. 예약 시각 이후 재시도도 멱등적이다.
        const planned = scheduled_at === undefined || scheduled_at === null
          ? null
          : scheduledInstant(scheduled_at);
        const modern = action === "schedule" || source === "dashboard" ||
          scheduled_at !== undefined;
        const result = await rpc(
          modern ? "notification_schedule" : "notification_enqueue",
          {
            p_job_id: job_id,
            p_title: title,
            p_body: message,
            p_target_ids: all === true ? null : installation_ids,
            ...(modern
              ? { p_scheduled_at: planned, p_source: "dashboard" }
              : {}),
          },
        );
        return respond(200, result);
      }
      if (action === "status") {
        return respond(
          200,
          await rpc("notification_job_status", { p_job_id: job_id }),
        );
      }
      if (!send) return respond(503, { error: "firebase_not_configured" });
      const maxBatches = body.max_batches ?? 1;
      if (
        !Number.isInteger(maxBatches) || (maxBatches as number) < 1 ||
        (maxBatches as number) > 20
      ) {
        throw new InvalidRequest();
      }
      const deadline = monotonicNow() + 30_000;
      let claimed = 0, recorded = 0, unrecorded = 0;
      // 5개 동시 처리, 최대 20회. 30초 후 새 배치를 시작하지 않고 진행 중인 결과는 기록한다.
      for (let batch = 0; batch < (maxBatches as number); batch++) {
        if (batch > 0 && monotonicNow() >= deadline) break;
        const claims = await rpc("notification_claim", {
          p_job_id: job_id ?? null,
          p_limit: 5,
        }) as Claim[];
        if (!Array.isArray(claims) || claims.length > 5) throw new Error();
        if (claims.length === 0) break;
        // 각 설치의 결과를 독립적으로 기록하여 일부 실패가 성공한 대상의 재발송을 만들지 않게 한다.
        const results = await Promise.all(claims.map(async (claim) => {
          const identity = {
            p_job_id: claim.job_id,
            p_installation_id: claim.installation_id,
            p_claim_id: claim.claim_id,
          };
          try {
            const current = await rpc(
              "notification_delivery_current",
              identity,
            );
            let outcome: string = "skipped";
            let retrySeconds = 60;
            if (current === true) {
              let result: SendResult;
              try {
                result = await send(claim.fcm_token, {
                  title: claim.title,
                  body: claim.body,
                });
              } catch {
                result = { kind: "unknown" };
              }
              outcome = result.kind === "unregistered"
                ? "invalid"
                : result.kind;
              if (result.kind === "retry") {
                retrySeconds = Math.ceil(result.retryAfterSeconds);
                if (!Number.isFinite(retrySeconds) || retrySeconds > 86400) {
                  outcome = "failed";
                }
                retrySeconds = Math.max(
                  60,
                  Math.min(86400, retrySeconds || 60),
                );
              }
            } else if (current !== false) throw new Error();
            const recorded = await rpc("notification_finish", {
              ...identity,
              p_outcome: outcome,
              p_retry_seconds: retrySeconds,
            });
            return recorded === true ? "recorded" : "unrecorded";
          } catch {
            return "unrecorded";
          }
        }));
        claimed += claims.length;
        recorded += results.filter((x) => x === "recorded").length;
        unrecorded += results.filter((x) => x !== "recorded").length;
        // 결과 저장 장애 때 추가 발송을 늘리지 않는다. 다음 워커가 기존 상태를 확인한다.
        if (unrecorded > 0) break;
      }
      return respond(200, { claimed, recorded, unrecorded });
    } catch (error) {
      if (
        error instanceof InvalidRequest ||
        error instanceof RpcError && error.code === "PT400"
      ) return respond(400, { error: "invalid_request" });
      if (error instanceof RpcError && error.code === "PT409") {
        return respond(409, { error: "request_conflict" });
      }
      if (error instanceof RpcError && error.code === "PT404") {
        return respond(404, { error: "job_not_found" });
      }
      return respond(503, { error: "temporarily_unavailable" });
    }
  };
}
