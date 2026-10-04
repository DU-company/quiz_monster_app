import { prepareSecrets } from "./prepare-notification-secrets.ts";
Deno.test("secrets file is private, valid and never overwrites existing output", async () => {
  const folder = await Deno.makeTempDir();
  const source = `${folder}/account.json`;
  const output = `${folder}/notification.env`;
  const account = {
    type: "service_account",
    project_id: "quiz-test",
    client_email: "test@quiz-test.iam.gserviceaccount.com",
    private_key:
      "-----BEGIN PRIVATE KEY-----\nfake-test-key\n-----END PRIVATE KEY-----\n",
  };
  try {
    await Deno.writeTextFile(source, JSON.stringify(account));
    await prepareSecrets(source, output);
    const text = await Deno.readTextFile(output);
    const [firebase, key] = text.trim().split("\n");
    const raw = firebase.substring(
      "FIREBASE_SERVICE_ACCOUNT='".length,
      firebase.length - 1,
    );
    if (
      JSON.parse(raw).private_key !== account.private_key ||
      !/^NOTIFICATION_SEND_KEY=[a-f0-9]{64}$/.test(key)
    ) throw new Error("invalid secret serialization");
    const mode = (await Deno.stat(output)).mode;
    if (mode !== null && (mode & 0o777) !== 0o600) {
      throw new Error("unsafe mode");
    }
    let refused = false;
    try {
      await prepareSecrets(source, output);
    } catch {
      refused = true;
    }
    if (!refused || await Deno.readTextFile(output) !== text) {
      throw new Error("existing output overwritten");
    }
    await Deno.writeTextFile(source, "{}");
    let invalid = false;
    try {
      await prepareSecrets(source, `${folder}/invalid.env`);
    } catch {
      invalid = true;
    }
    if (!invalid) throw new Error("malformed account accepted");
  } finally {
    await Deno.remove(folder, { recursive: true });
  }
});
