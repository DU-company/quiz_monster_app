export type Rpc = (
  name: string,
  params: Record<string, unknown>,
) => Promise<unknown>;
export class RpcError extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
  }
}
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const respond = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
class InvalidRequest extends Error {}
async function readBody(request: Request): Promise<Record<string, unknown>> {
  if (!request.body) throw new InvalidRequest();
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    // Content-Length와 무관하게 실제 수신 바이트를 제한한다.
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.length;
      if (length > 8192) {
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
  let body: unknown;
  try {
    body = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } catch {
    throw new InvalidRequest();
  }
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    throw new InvalidRequest();
  }
  return body as Record<string, unknown>;
}
export function createHandler(rpc: Rpc) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return respond(405, { error: "method_not_allowed" });
    }
    if (
      request.headers.get("content-type")?.split(";")[0].trim()
        .toLowerCase() !== "application/json"
    ) {
      return respond(415, { error: "unsupported_media_type" });
    }
    const secret = request.headers.get("X-Installation-Secret");
    if (!secret || !/^[0-9a-f]{64}$/.test(secret)) {
      return respond(401, { error: "installation_auth_failed" });
    }
    try {
      const body = await readBody(request);
      const { action, installation_id } = body;
      if (
        (action !== "register" && action !== "sync") ||
        typeof installation_id !== "string" ||
        !uuid.test(installation_id)
      ) throw new InvalidRequest();
      if (action === "sync") {
        const { revision, enabled, fcm_token } = body;
        if (
          !Number.isSafeInteger(revision) || (revision as number) <= 0 ||
          typeof enabled !== "boolean" ||
          !(fcm_token === null ||
            (typeof fcm_token === "string" && fcm_token.trim().length > 0 &&
              fcm_token.length <= 4096)) ||
          (enabled && fcm_token === null)
        ) {
          throw new InvalidRequest();
        }
      }
      // IP 헤더를 신뢰하지 않고 DB에 공유되는 전역·설치별 한도를 적용한다.
      const globalAllowed = await rpc("notification_take_rate_limit", {
        p_bucket: `global:${action}`,
        p_limit: action === "register" ? 30 : 1000,
        p_window_seconds: 60,
      });
      if (globalAllowed !== true) {
        return respond(429, { error: "rate_limited" });
      }
      const installationAllowed = await rpc("notification_take_rate_limit", {
        p_bucket: `installation:${installation_id.toLowerCase()}`,
        p_limit: 60,
        p_window_seconds: 60,
      });
      if (installationAllowed !== true) {
        return respond(429, { error: "rate_limited" });
      }
      const digest = await crypto.subtle.digest(
        "SHA-256",
        new TextEncoder().encode(secret),
      );
      const hash = Array.from(
        new Uint8Array(digest),
        (v) => v.toString(16).padStart(2, "0"),
      ).join("");
      const params: Record<string, unknown> = {
        p_installation_id: installation_id.toLowerCase(),
        p_credential_hash: hash,
      };
      if (action === "sync") {
        Object.assign(params, {
          p_revision: body.revision,
          p_enabled: body.enabled,
          p_fcm_token: body.fcm_token,
        });
      }
      const result = await rpc(
        action === "register" ? "notification_register" : "notification_sync",
        params,
      );
      // RPC 응답 중 공개 계약 필드만 반환하여 토큰과 인증 정보 노출을 막는다.
      const value = result as Record<string, unknown> | null;
      if (
        !value || !Number.isSafeInteger(value.revision) ||
        (value.revision as number) < 0 ||
        typeof value.enabled !== "boolean"
      ) throw new Error("invalid_rpc_response");
      return respond(200, { revision: value.revision, enabled: value.enabled });
    } catch (error) {
      if (error instanceof InvalidRequest) {
        return respond(400, { error: "invalid_request" });
      }
      if (error instanceof RpcError) {
        if (error.code === "PT401") {
          return respond(401, { error: "installation_auth_failed" });
        }
        if (
          error.code === "PT409" &&
          ["revision_conflict", "token_conflict"].includes(error.message)
        ) {
          return respond(409, { error: error.message });
        }
      }
      return respond(503, { error: "temporarily_unavailable" });
    }
  };
}
export function createRestRpc(
  url: string,
  serviceKey: string,
  fetcher: typeof fetch = fetch,
): Rpc {
  return async (name, params) => {
    const response = await fetcher(
      `${url.replace(/\/$/, "")}/rest/v1/rpc/${name}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
        },
        body: JSON.stringify(params),
        signal: AbortSignal.timeout(10000),
      },
    );
    const body = await response.json();
    if (!response.ok) {
      throw new RpcError(
        typeof body?.code === "string" ? body.code : "",
        typeof body?.message === "string" ? body.message : "rpc_failed",
      );
    }
    return body;
  };
}
