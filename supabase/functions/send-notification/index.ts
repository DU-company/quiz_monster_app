import { createRestRpc } from "../notification-installations/handler.ts";
import { createFcmSender } from "./fcm.ts";
import { createSendHandler } from "./handler.ts";

const url = Deno.env.get("SUPABASE_URL");
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const secret = Deno.env.get("NOTIFICATION_SEND_KEY") ?? "";
let sender: ReturnType<typeof createFcmSender> | null = null;
try {
  const account = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (account) sender = createFcmSender(JSON.parse(account));
} catch { /* 설정 원문이나 비밀키를 오류 로그에 남기지 않는다. */ }
const handler = url && key
  ? createSendHandler(createRestRpc(url, key), sender, secret)
  : () =>
    new Response(JSON.stringify({ error: "sender_not_configured" }), {
      status: 503,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
      },
    });
Deno.serve(handler);
