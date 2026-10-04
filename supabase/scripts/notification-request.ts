// 키는 환경변수로만 받고 요청 JSON 파일에는 작업 ID·문구·대상만 넣는다.
export async function runRequest(
  args: string[],
  env: (name: string) => string | undefined,
  read: (path: string) => Promise<string>,
  fetcher: typeof fetch = fetch,
) {
  if (args.length !== 1) {
    throw new Error("요청 JSON 파일 경로 하나를 지정하세요.");
  }
  const url = new URL(env("NOTIFICATION_API_URL") ?? "");
  const secret = env("NOTIFICATION_SEND_KEY") ?? "";
  if (
    (url.protocol !== "https:" &&
      !(url.protocol === "http:" &&
        ["localhost", "127.0.0.1"].includes(url.hostname))) ||
    url.username || url.password || url.search || url.hash ||
    !/^[a-f0-9]{64}$/.test(secret)
  ) throw new Error("발송 URL과 서버 키 환경변수를 확인하세요.");
  const request = JSON.parse(await read(args[0]));
  if (!request || !["enqueue", "process", "status"].includes(request.action)) {
    throw new Error("action은 enqueue/process/status 중 하나여야 합니다.");
  }
  const response = await fetcher(url, {
    method: "POST",
    redirect: "error",
    headers: {
      "Content-Type": "application/json",
      "X-Notification-Key": secret,
    },
    body: JSON.stringify(request),
    signal: AbortSignal.timeout(120000),
  });
  if (!response.ok) {
    throw new Error(
      `발송 API 오류 (HTTP ${response.status}). 같은 작업 ID의 상태를 확인하세요.`,
    );
  }
  return await response.json();
}
if (import.meta.main) {
  try {
    console.log(
      JSON.stringify(
        await runRequest(Deno.args, Deno.env.get, Deno.readTextFile),
        null,
        2,
      ),
    );
  } catch {
    console.error(
      "요청 실패: URL·키·요청 파일을 확인하고, 재전송 전에 같은 작업 ID로 status를 조회하세요.",
    );
    Deno.exitCode = 1;
  }
}
