export type SendResult =
  | { kind: "sent" }
  | { kind: "unregistered" }
  | { kind: "retry"; retryAfterSeconds: number }
  | { kind: "failed" }
  | { kind: "unknown" };

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};
const oauthUrl = "https://oauth2.googleapis.com/token";
const encoder = new TextEncoder();
const algorithm = { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" };
const base64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replace(/=/g, "").replace(/\+/g, "-")
    .replace(/\//g, "_");
const encodedJson = (value: unknown) =>
  base64url(encoder.encode(JSON.stringify(value)));

function retryDelay(response: Response, now: number): number {
  const value = response.headers.get("retry-after");
  if (!value) return 60;
  const seconds = /^\d+$/.test(value)
    ? Number(value)
    : (Date.parse(value) - now) / 1000;
  return Number.isFinite(seconds) ? Math.max(60, Math.ceil(seconds)) : 60;
}

export function createFcmSender(
  account: ServiceAccount,
  fetcher: typeof fetch = fetch,
  now: () => number = Date.now,
): (
  token: string,
  notification: { title: string; body: string },
) => Promise<SendResult> {
  let cached: { token: string; expiresAt: number } | undefined;
  let refreshing: Promise<string | SendResult> | undefined;
  let privateKey: CryptoKey | undefined;

  async function refresh(): Promise<string | SendResult> {
    try {
      if (
        !/^[a-z][a-z0-9-]{4,61}[a-z0-9]$/.test(account.project_id) ||
        !account.client_email.endsWith(".iam.gserviceaccount.com")
      ) return { kind: "failed" };
      if (!privateKey) {
        const pem = account.private_key.replace(
          /-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,
          "",
        );
        privateKey = await crypto.subtle.importKey(
          "pkcs8",
          Uint8Array.from(atob(pem), (char) => char.charCodeAt(0)),
          algorithm,
          false,
          ["sign"],
        );
      }
      const issuedAt = Math.floor(now() / 1000);
      const unsigned = `${encodedJson({ alg: "RS256", typ: "JWT" })}.${
        encodedJson({
          iss: account.client_email,
          scope: "https://www.googleapis.com/auth/firebase.messaging",
          aud: oauthUrl,
          iat: issuedAt,
          exp: issuedAt + 3600,
        })
      }`;
      const signature = await crypto.subtle.sign(
        algorithm,
        privateKey,
        encoder.encode(unsigned),
      );
      const assertion = `${unsigned}.${base64url(new Uint8Array(signature))}`;
      let response: Response;
      try {
        response = await fetcher(oauthUrl, {
          method: "POST",
          redirect: "error",
          signal: AbortSignal.timeout(10_000),
          body: new URLSearchParams({
            grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
            assertion,
          }),
        });
      } catch {
        // OAuth 실패 시에는 아직 FCM에 메시지를 보내지 않았으므로 재시도가 안전하다.
        return { kind: "retry", retryAfterSeconds: 60 };
      }
      if (!response.ok) {
        await response.body?.cancel();
        return response.status === 429 || response.status >= 500
          ? { kind: "retry", retryAfterSeconds: retryDelay(response, now()) }
          : { kind: "failed" };
      }
      const result = await response.json();
      if (
        typeof result.access_token !== "string" || !result.access_token ||
        typeof result.expires_in !== "number" ||
        !Number.isFinite(result.expires_in) || result.expires_in <= 0
      ) {
        return { kind: "failed" };
      }
      cached = {
        token: result.access_token,
        expiresAt: now() + Math.min(result.expires_in, 3600) * 1000,
      };
      return cached.token;
    } catch {
      return { kind: "failed" };
    }
  }

  async function accessToken(): Promise<string | SendResult> {
    if (cached && cached.expiresAt > now() + 60_000) return cached.token;
    // 동시에 들어온 발송 요청은 하나의 OAuth 갱신 결과를 공유한다.
    refreshing ??= refresh();
    try {
      return await refreshing;
    } finally {
      refreshing = undefined;
    }
  }

  return async (token, notification) => {
    const access = await accessToken();
    if (typeof access !== "string") return access;
    try {
      const response = await fetcher(
        `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
        {
          method: "POST",
          redirect: "error",
          signal: AbortSignal.timeout(10_000),
          headers: {
            authorization: `Bearer ${access}`,
            "content-type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token,
              notification,
              apns: {
                headers: {
                  "apns-push-type": "alert",
                  "apns-priority": "10",
                },
                payload: {
                  aps: {
                    alert: notification,
                    sound: "default",
                    "interruption-level": "active",
                  },
                },
              },
            },
          }),
        },
      );
      if (response.ok) {
        await response.body?.cancel();
        return { kind: "sent" };
      }
      if (response.status === 401) cached = undefined;
      if (
        response.status === 429 || response.status === 500 ||
        response.status === 503
      ) {
        await response.body?.cancel();
        return {
          kind: "retry",
          retryAfterSeconds: retryDelay(response, now()),
        };
      }
      const result = await response.json().catch(() => null);
      const details = result?.error?.details;
      // 일반 404나 INVALID_ARGUMENT는 토큰 폐기 근거가 아니므로 FCM 상세 코드를 확인한다.
      if (
        response.status === 404 && Array.isArray(details) &&
        details.some((detail) =>
          detail?.["@type"] ===
            "type.googleapis.com/google.firebase.fcm.v1.FcmError" &&
          detail.errorCode === "UNREGISTERED"
        )
      ) return { kind: "unregistered" };
      return { kind: "failed" };
    } catch {
      // 응답을 잃은 발송은 성공 여부를 알 수 없으므로 자동 재발송하지 않는다.
      return { kind: "unknown" };
    }
  };
}
