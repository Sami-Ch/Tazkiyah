import { createInterface } from "node:readline/promises";
import { Writable } from "node:stream";
import { hashPassword } from "better-auth/crypto";
import pg from "pg";

async function readPassword() {
  if (!process.stdin.isTTY) {
    // A caller can pipe a password from its secret store.
    let password = "";
    for await (const chunk of process.stdin.setEncoding("utf8")) {
      password += chunk;
      if (password.length > 130) throw new Error("Password is too long.");
    }
    return password.replace(/\r?\n$/, "");
  }

  const hidden = new Writable({
    write(_chunk, _encoding, done) {
      done();
    },
  });
  const prompt = createInterface({
    input: process.stdin,
    output: hidden,
    terminal: true,
  });
  try {
    const controller = new AbortController();
    prompt.once("SIGINT", () => controller.abort());
    process.stderr.write("Admin password: ");
    const password = await prompt.question("", { signal: controller.signal });
    process.stderr.write("\nConfirm password: ");
    if (
      password !== (await prompt.question("", { signal: controller.signal }))
    ) {
      throw new Error("The passwords do not match.");
    }
    return password;
  } finally {
    prompt.close();
    process.stderr.write("\n");
  }
}

async function main() {
  const [rawDomain, rawEmail, rawName, ...extra] = process.argv.slice(2);
  const domain = rawDomain?.trim().toLowerCase();
  const email = rawEmail?.trim().toLowerCase();
  const name = rawName?.trim();
  if (
    !domain ||
    !/^[a-z0-9]+(?:[.-][a-z0-9]+)+$/.test(domain) ||
    !email ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
    !name ||
    extra.length
  ) {
    throw new Error(
      'Usage: npm run db:bootstrap-admin -- <domain> <email> "<full name>"',
    );
  }

  const connectionString = process.env.MIGRATION_DATABASE_URL;
  if (!connectionString || !URL.canParse(connectionString)) {
    throw new Error(
      "Set MIGRATION_DATABASE_URL to the direct database administrator connection.",
    );
  }
  const { protocol, hostname, searchParams } = new URL(connectionString);
  if (
    !["postgres:", "postgresql:"].includes(protocol) ||
    (searchParams.get("host") ?? hostname)
      .toLowerCase()
      .split(".")[0]
      .endsWith("-pooler")
  ) {
    throw new Error("Use a direct Postgres connection for account setup.");
  }
  const password = await readPassword();
  if (
    password.length < 16 ||
    password.length > 128 ||
    /[\r\n]/.test(password)
  ) {
    throw new Error("Choose a password with 16 to 128 characters.");
  }
  const hash = await hashPassword(password);
  const client = new pg.Client({
    connectionString,
    connectionTimeoutMillis: 5_000,
  });

  try {
    await client.connect();
    await client.query("begin");
    await client.query("set local role tazkiyah_schema_owner");
    const {
      rows: [settings],
    } = await client.query(
      `select institute_id, principal_user_id from app.institute_settings
       where institute_id = app.resolve_institute($1)
       for update`,
      [domain],
    );
    if (!settings)
      throw new Error(
        "Seed the institute and its domain before creating the first admin.",
      );

    const instituteId = settings.institute_id;
    const { rowCount } = await client.query(
      `select 1 from app.user_roles where institute_id = $1 and role = 'admin'`,
      [instituteId],
    );
    if (settings.principal_user_id || rowCount) {
      throw new Error("This institute already has an admin or principal.");
    }
    const {
      rows: [user],
    } = await client.query(
      `insert into app.users (institute_id, email, full_name, status, email_verified, must_change_password)
       values ($1, $2, $3, 'active', true, false)
       on conflict do nothing
       returning id`,
      [instituteId, email, name],
    );
    if (!user)
      throw new Error("An account already uses that email at this institute.");

    await client.query(
      `insert into identity.accounts (institute_id, user_id, provider_id, account_id, password)
       values ($1, $2, 'credential', $2::uuid::text, $3)`,
      [instituteId, user.id, hash],
    );
    await client.query(
      "insert into app.user_roles (institute_id, user_id, role) values ($1, $2, 'admin')",
      [instituteId, user.id],
    );
    await client.query(
      "update app.institute_settings set principal_user_id = $2 where institute_id = $1",
      [instituteId, user.id],
    );
    await client.query(
      `insert into app.audit_log (institute_id, actor_kind, action, entity_table, entity_id)
       values ($1, 'system', 'admin.bootstrap', 'users', $2)`,
      [instituteId, user.id],
    );
    await client.query("commit");
    console.log("First admin and principal created.");
  } catch (error) {
    await client.query("rollback").catch(() => {});
    throw error;
  } finally {
    await client.end();
  }
}

try {
  await main();
} catch (error) {
  // PostgreSQL's detail field can contain account data or credentials.
  const message =
    error instanceof Error && !("code" in error)
      ? error.message
      : "Admin setup failed.";
  console.error(message);
  process.exitCode = 1;
}
