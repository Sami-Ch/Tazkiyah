import { readFileSync } from "node:fs";
import { PGlite } from "@electric-sql/pglite";
import { PGLiteSocketServer } from "@electric-sql/pglite-socket";
import { base32 } from "@better-auth/utils/base32";
import { createOTP } from "@better-auth/utils/otp";
import { hashPassword } from "better-auth/crypto";
import { readMigrationFiles } from "drizzle-orm/migrator";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

// Runs the real Better Auth handler against the migrated schema in PGlite,
// connected as tazkiyah_auth through a local Postgres socket.
const origin = "http://localhost:3000";
const password = "correct horse battery staple";
const port = 55000 + Math.floor(Math.random() * 5000);
const db = new PGlite();
const server = new PGLiteSocketServer({ db, port, host: "127.0.0.1" });
let auth: typeof import("./auth");

const staff = {
  admin: "21000000-0000-4000-8000-000000000001",
  finance: "21000000-0000-4000-8000-000000000002",
  editor: "21000000-0000-4000-8000-000000000003",
  donor: "21000000-0000-4000-8000-000000000004",
} as const;
let enrolledAdmin: Browser;

beforeAll(async () => {
  for (const migration of readMigrationFiles({
    migrationsFolder: new URL("../../../../db/drizzle/", import.meta.url)
      .pathname,
  })) {
    await db.exec(`begin;\n${migration.sql.join("\n")}\ncommit;`);
  }
  await db.exec(
    readFileSync(
      new URL("../../../../db/seed/markaz_al_azeem.sql", import.meta.url),
      "utf8",
    ),
  );
  const hash = await hashPassword(password);
  for (const [role, id] of [
    ["admin", staff.admin],
    ["finance_officer", staff.finance],
    ["editor", staff.editor],
    ["donor", staff.donor],
  ]) {
    await db.query(
      `with tenant as (select institute_id from app.institute_domains where domain = 'azeem-lateef.com')
       insert into app.users (id, institute_id, email, full_name, status, must_change_password)
       select $1, institute_id, $2, 'Fixture ' || $3, 'active', false from tenant`,
      [id, `${role}@example.test`, role],
    );
    // Donors hold no row in user_roles until donor accounts arrive (P0-E5-T02).
    if (role !== "donor")
      await db.query(
        `insert into app.user_roles (institute_id, user_id, role)
         select institute_id, id, $2 from app.users where id = $1`,
        [id, role],
      );
    await db.query(
      `insert into identity.accounts (institute_id, user_id, provider_id, account_id, password)
       select institute_id, id, 'credential', id::text, $2 from app.users where id = $1`,
      [id, hash],
    );
  }
  // Every socket connection shares this backend session and its role.
  await db.exec("set role tazkiyah_auth");
  await server.start();
  Object.assign(process.env, {
    AUTH_DATABASE_URL: `postgres://postgres@127.0.0.1:${port}/postgres`,
    BETTER_AUTH_LOCAL_ORIGIN: origin,
    BETTER_AUTH_LOCAL_INSTITUTE_DOMAIN: "azeem-lateef.com",
    BETTER_AUTH_SECRET: "test-secret-".padEnd(48, "x"),
  });
  auth = await import("./auth");
}, 60_000);

afterAll(async () => {
  await server.stop();
  await db.close();
});

class Browser {
  cookies = new Map<string, string>();
  setCookies: string[] = [];

  headers() {
    return new Headers({
      host: "localhost:3000",
      cookie: [...this.cookies].map(([k, v]) => `${k}=${v}`).join("; "),
    });
  }

  async post(path: string, body: object) {
    const headers = this.headers();
    headers.set("origin", origin);
    headers.set("content-type", "application/json");
    const response = await auth.handleAuth(
      new Request(`${origin}/api/auth${path}`, {
        method: "POST",
        headers,
        body: JSON.stringify(body),
      }),
    );
    this.setCookies = response.headers.getSetCookie();
    for (const cookie of this.setCookies) {
      const [pair, ...attributes] = cookie.split(";");
      const [name, value] = pair.split("=");
      if (attributes.some((a) => /max-age=0/i.test(a)) || value === "")
        this.cookies.delete(name);
      else this.cookies.set(name, value);
    }
    return {
      status: response.status,
      json: await response.json().catch(() => null),
    };
  }

  async get(path: string) {
    const response = await auth.handleAuth(
      new Request(`${origin}/api/auth${path}`, { headers: this.headers() }),
    );
    return { status: response.status, json: await response.json() };
  }

  access() {
    return auth.getAdminAccess(this.headers());
  }
}

// Better Auth also allows 3 two-factor requests per 10 seconds per IP. Clearing
// that bucket stands in for attempts spread over time, so the lockout is tested.
async function spreadOverTime() {
  await db.exec(
    "reset role; delete from identity.rate_limit; set role tazkiyah_auth",
  );
}

async function codeFor(totpURI: string, offsetPeriods = 0) {
  const secret = new URL(totpURI).searchParams.get("secret")!;
  const otp = createOTP(base32.decode(secret));
  return offsetPeriods === 0
    ? otp.totp()
    : otp.hotp(Math.floor(Date.now() / 30_000) + offsetPeriods);
}

async function enrol(browser: Browser, email: string) {
  await browser.post("/sign-in/email", { email, password });
  const enabled = await browser.post("/two-factor/enable", { password });
  const verified = await browser.post("/two-factor/verify-totp", {
    code: await codeFor(enabled.json.totpURI),
    trustDevice: true,
  });
  return { enabled, verified };
}

describe("two-factor for admin and finance officer (03 §6.4)", () => {
  it("sends an admin who has not enrolled to enrolment and nowhere else", async () => {
    const browser = new Browser();
    const signIn = await browser.post("/sign-in/email", {
      email: "admin@example.test",
      password,
    });
    expect(signIn.status).toBe(200);
    expect(await browser.access()).toEqual({ state: "enroll" });
  });

  it("does not ask an editor for two-factor", async () => {
    const browser = new Browser();
    await browser.post("/sign-in/email", {
      email: "editor@example.test",
      password,
    });
    expect(await browser.access()).toMatchObject({
      state: "allowed",
      canEditPages: true,
      canInvite: false,
      canRecordTransfers: false,
    });
  });

  it("issues 10 backup codes, ignores trust-this-device and then allows access", async () => {
    const browser = new Browser();
    const { enabled, verified } = await enrol(browser, "admin@example.test");
    expect(enabled.status).toBe(200);
    expect(enabled.json.backupCodes).toHaveLength(10);
    expect(verified.status).toBe(200);
    expect(browser.setCookies.join(";")).not.toMatch(/trust_device/);
    expect(await browser.access()).toMatchObject({
      state: "allowed",
      canInvite: true,
      canRecordTransfers: true,
    });
    enrolledAdmin = browser;
  });

  it("asks for a code at every later sign-in", async () => {
    const browser = new Browser();
    const signIn = await browser.post("/sign-in/email", {
      email: "admin@example.test",
      password,
    });
    expect(signIn.json).toMatchObject({ twoFactorRedirect: true });
    expect(await browser.access()).toEqual({ state: "signed-out" });
  });

  it("locks the account for 15 minutes after 5 wrong codes", async () => {
    const setup = new Browser();
    const { enabled } = await enrol(setup, "finance_officer@example.test");
    const browser = new Browser();
    await browser.post("/sign-in/email", {
      email: "finance_officer@example.test",
      password,
    });
    for (let attempt = 1; attempt <= 5; attempt++) {
      await spreadOverTime();
      const wrong = await browser.post("/two-factor/verify-totp", {
        code: await codeFor(enabled.json.totpURI, 10),
      });
      // The fifth failure itself may already report the lock.
      expect([401, ...(attempt === 5 ? [429] : [])]).toContain(wrong.status);
    }
    await spreadOverTime();
    const locked = await browser.post("/two-factor/verify-totp", {
      code: await codeFor(enabled.json.totpURI),
    });
    expect(locked.status).toBe(429);
    await db.exec("reset role");
    const [lock] = (
      await db.query<{ minutes: number }>(
        `select round(extract(epoch from locked_until - now()) / 60) as minutes
         from identity.two_factor where user_id = $1`,
        [staff.finance],
      )
    ).rows;
    await db.exec("set role tazkiyah_auth");
    expect(Number(lock.minutes)).toBe(15);
  });
});

async function asOwner<T>(query: string, params: unknown[] = []) {
  await db.exec("reset role");
  try {
    return (await db.query<T>(query, params)).rows;
  } finally {
    await db.exec("set role tazkiyah_auth");
  }
}

async function lifetimeDays(userId: string) {
  const [row] = await asOwner<{ days: string }>(
    `select round(extract(epoch from max(expires_at) - now()) / 3600) / 24 as days
     from identity.sessions where user_id = $1`,
    [userId],
  );
  return Number(row.days);
}

function idleFor(userId: string, interval: string) {
  return asOwner(
    `update identity.sessions set updated_at = now() - $2::interval where user_id = $1`,
    [userId, interval],
  );
}

describe("session rules per role (03 §6.5)", () => {
  it("caps each session at its role group's lifetime", async () => {
    for (const email of ["editor@example.test", "donor@example.test"])
      await new Browser().post("/sign-in/email", { email, password });
    expect(await lifetimeDays(staff.admin)).toBe(0.5);
    expect(await lifetimeDays(staff.editor)).toBe(30);
    expect(await lifetimeDays(staff.donor)).toBe(90);
  });

  it("ends an admin session after 30 idle minutes", async () => {
    expect(await enrolledAdmin.access()).toMatchObject({ state: "allowed" });
    await idleFor(staff.admin, "29 minutes");
    expect(await enrolledAdmin.access()).toMatchObject({ state: "allowed" });
    await idleFor(staff.admin, "31 minutes");
    expect(await enrolledAdmin.access()).toEqual({ state: "signed-out" });
  });

  it("ends an editor session after 7 idle days and a donor's after 30", async () => {
    const editor = new Browser();
    await editor.post("/sign-in/email", {
      email: "editor@example.test",
      password,
    });
    await idleFor(staff.editor, "6 days");
    expect(await editor.access()).toMatchObject({ state: "allowed" });
    await idleFor(staff.editor, "7 days 1 minute");
    expect(await editor.access()).toEqual({ state: "signed-out" });

    const donor = new Browser();
    await donor.post("/sign-in/email", {
      email: "donor@example.test",
      password,
    });
    await idleFor(staff.donor, "29 days");
    expect((await donor.get("/get-session")).json).toMatchObject({
      user: { email: "donor@example.test" },
    });
    await idleFor(staff.donor, "30 days 1 minute");
    const sessions = () =>
      asOwner(`select from identity.sessions where user_id = $1`, [
        staff.donor,
      ]);
    const before = (await sessions()).length;
    expect((await donor.get("/get-session")).json).toBeNull();
    expect(await sessions()).toHaveLength(before - 1);
  });

  it("signs a user out of all devices", async () => {
    const phone = new Browser();
    const laptop = new Browser();
    for (const device of [phone, laptop])
      await device.post("/sign-in/email", {
        email: "editor@example.test",
        password,
      });
    expect(await laptop.access()).toMatchObject({ state: "allowed" });
    expect((await phone.post("/revoke-sessions", {})).status).toBe(200);
    expect(await laptop.access()).toEqual({ state: "signed-out" });
    expect(await phone.access()).toEqual({ state: "signed-out" });
  });
});

describe("auth events in the audit log (P0-E5-T10)", () => {
  it("records sign-ins and failed codes with IDs only", async () => {
    const rows = await asOwner<{
      action: string;
      entity_id: string;
      row: string;
    }>(
      `select action, entity_id, a::text as row from app.audit_log a
       where action like 'auth.%'`,
    );
    expect(rows).toContainEqual(
      expect.objectContaining({
        action: "auth.signed_in",
        entity_id: staff.editor,
      }),
    );
    expect(
      rows.filter(
        (r) =>
          r.action === "auth.two_factor_failed" &&
          r.entity_id === staff.finance,
      ).length,
    ).toBeGreaterThanOrEqual(5);
    expect(rows.filter((r) => /@example\.test|password/.test(r.row))).toEqual(
      [],
    );
  });
});
