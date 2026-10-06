// 서비스 계정과 발송 키는 권한 0600인 별도 파일에만 저장하고 콘솔에 출력하지 않는다.
export async function prepareSecrets(accountPath: string, outputPath: string) {
  const account = JSON.parse(await Deno.readTextFile(accountPath));
  if (
    account.type !== "service_account" ||
    typeof account.project_id !== "string" ||
    typeof account.client_email !== "string" ||
    typeof account.private_key !== "string" ||
    !account.private_key.includes("BEGIN PRIVATE KEY")
  ) throw new Error("서비스 계정 JSON을 확인하세요.");
  const key = [...crypto.getRandomValues(new Uint8Array(32))].map((v) =>
    v.toString(16).padStart(2, "0")
  ).join("");
  // dotenv의 단일 인용부호로 감싸 JSON 내부의 개행 이스케이프를 유지한다.
  const value = JSON.stringify({
    project_id: account.project_id,
    client_email: account.client_email,
    private_key: account.private_key,
  });
  if (value.includes("'")) throw new Error("서비스 계정 형식을 확인하세요.");
  const file = await Deno.open(outputPath, {
    write: true,
    createNew: true,
    mode: 0o600,
  });
  try {
    const data = new TextEncoder().encode(
      `FIREBASE_SERVICE_ACCOUNT='${value}'\nNOTIFICATION_SEND_KEY=${key}\n`,
    );
    let offset = 0;
    while (offset < data.length) {
      offset += await file.write(data.subarray(offset));
    }
  } finally {
    file.close();
  }
}
if (import.meta.main) {
  try {
    if (Deno.args.length !== 2) throw new Error();
    await prepareSecrets(Deno.args[0], Deno.args[1]);
    console.log(
      "서버 설정 파일 생성 완료. 내용은 공유하지 말고 Supabase secrets로 등록하세요.",
    );
  } catch {
    console.error(
      "생성 실패: 입력 JSON·출력 경로를 확인하세요. 기존 파일은 덮어쓰지 않습니다.",
    );
    Deno.exitCode = 1;
  }
}
