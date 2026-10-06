import { createHandler, createRestRpc } from "./handler.ts";
const url = Deno.env.get("SUPABASE_URL");
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const handler = url && key
  ? createHandler(createRestRpc(url, key))
  : () =>
    new Response(JSON.stringify({ error: "temporarily_unavailable" }), {
      status: 503,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
      },
    });
Deno.serve(handler);
