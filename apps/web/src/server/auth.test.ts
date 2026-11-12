import { readFileSync } from "node:fs";
import { PGlite } from "@electric-sql/pglite";
import { PGLiteSocketServer } from "@electric-sql/pglite-socket";
import { base32 } from "@better-auth/utils/base32";
import { createOTP } from "@better-auth/utils/otp";
import { hashPassword } from "better-auth/crypto";
import { readMigrationFiles } from "drizzle-orm/migrator";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { karachiDate } from "@/institutes/manual-donations";

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
  teacher: "21000000-0000-4000-8000-000000000005",
} as const;
const hifzClass = "21000000-0000-4000-8000-000000000051";
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
    ["teacher", staff.teacher],
  ]) {
    await db.query(
      `with tenant as (select institute_id from app.institute_domains where domain = 'azeem-lateef.com')
       insert into app.users (id, institute_id, email, full_name, status, must_change_password, email_verified)
       select $1, institute_id, $2, 'Fixture ' || $3, 'active', false, true from tenant`,
      [id, `${role}@example.test`, role],
    );
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
  // The teacher's class, which every new student joins (04 §7.4).
  await db.query(
    `insert into app.classes (id, institute_id, name, created_by)
     select $1, institute_id, '{"en":"Hifz 1"}', id from app.users where id = $2`,
    [hifzClass, staff.teacher],
  );
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

it("resolves the Vercel host for both API and server-rendered account requests and sends through Resend", async () => {
  const host = "azeem-lateef.com";
  const hosted = `https://${host}`;
  const requestHeaders = new Headers({
    host,
    origin: hosted,
    "content-type": "application/json",
    "x-forwarded-proto": "https",
    "x-vercel-forwarded-for": "192.0.2.42",
    "x-tazkiyah-auth-origin": "https://elsewhere.example.test",
  });
  const send = vi
    .fn<typeof fetch>()
    .mockResolvedValue(
      Response.json({ id: "00000000-0000-4000-8000-000000000001" }),
    );
  vi.stubGlobal("fetch", send);
  vi.stubEnv("VERCEL", "1");
  vi.stubEnv("RESEND_API_KEY", "re_fixture");
  vi.stubEnv("AUTH_EMAIL_FROM", "accounts@notify.example.test");

  function post(path: string, body: Record<string, string>) {
    return auth.handleAuth(
      new Request(`${origin}/api/auth${path}`, {
        method: "POST",
        headers: requestHeaders,
        body: JSON.stringify(body),
      }),
    );
  }

  try {
    const login = await post("/sign-in/email", {
      email: "editor@example.test",
      password,
    });
    expect(login.status).toBe(200);
    const cookies = login.headers.getSetCookie();
    expect(cookies.some((cookie) => cookie.includes("Secure"))).toBe(true);
    requestHeaders.set(
      "cookie",
      cookies.map((cookie) => cookie.split(";")[0]).join("; "),
    );
    expect(await auth.getAccountAccess(requestHeaders)).toMatchObject({
      state: "allowed",
      roles: ["editor"],
    });
    requestHeaders.delete("cookie");

    const signup = await post("/sign-up/email", {
      name: "Hosted Fixture",
      email: "vercel-donor@example.test",
      password,
      callbackURL: "/ur/sign-in",
      preferredLanguage: "ur",
    });
    expect(signup.status).toBe(200);
    expect(send).toHaveBeenCalledExactlyOnceWith(
      "https://api.resend.com/emails",
      expect.objectContaining({ method: "POST", body: expect.any(String) }),
    );
    const email = JSON.parse(String(send.mock.calls[0][1]?.body));
    expect(email.to).toEqual(["vercel-donor@example.test"]);
    expect(email.text).toContain(`${host}/api/auth/verify-email`);
    expect(email.text).not.toContain("Hosted Fixture");
  } finally {
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
  }
});

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
    expect(await auth.getAccountAccess(browser.headers())).toEqual({
      state: "enroll",
    });
    expect(await auth.getAccountAccess(new Browser().headers())).toEqual({
      state: "signed-out",
    });
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

  it("saves cause donation settings through the admin API and exposes the scholar after publication", async () => {
    const seeded = await auth.getCauseWorkspace(enrolledAdmin.headers());
    if (seeded.state !== "allowed") throw new Error("Missing admin access");
    expect(seeded.causes).toHaveLength(7);
    expect(
      seeded.causes.every(
        (cause) => cause.status === "draft" && !cause.accepts_zakat,
      ),
    ).toBe(true);
    expect(
      seeded.causes
        .filter((cause) => cause.receipt_public_by_default)
        .map((cause) => cause.slug)
        .sort(),
    ).toEqual(["electricity", "kitchen-gas", "wheat-stock"]);

    const draft = {
      kind: "ongoing",
      slug: "test-zakat-cause",
      title: { en: "Test cause", ur: "آزمائشی شعبہ" },
      summary: { en: "Test summary", ur: "آزمائشی خلاصہ" },
      body: { en: "", ur: "" },
      target: "",
      period: "monthly",
      starts: "",
      ends: "",
      zakat: true,
      scholar: { en: "Test scholar", ur: "" },
      receiptPublicByDefault: true,
    };
    const denied = await new Browser().post("/cause", {
      action: "create",
      ...draft,
    });
    expect(denied.status).toBe(403);
    const invalid = await enrolledAdmin.post("/cause", {
      action: "create",
      ...draft,
      zakat: false,
    });
    expect(invalid.status).toBe(400);
    const created = await enrolledAdmin.post("/cause", {
      action: "create",
      ...draft,
    });
    expect(created.status).toBe(201);

    const read = async () => {
      const workspace = await auth.getCauseWorkspace(enrolledAdmin.headers());
      expect(workspace.state).toBe("allowed");
      if (workspace.state !== "allowed")
        throw new Error("Missing admin access");
      return workspace.causes.find((cause) => cause.slug === draft.slug)!;
    };
    const cause = await read();
    expect(cause).toMatchObject({
      status: "draft",
      accepts_zakat: true,
      zakat_approved_by: { en: "Test scholar" },
      receipt_public_by_default: true,
    });
    const published = await enrolledAdmin.post("/cause", {
      action: "publish",
      id: cause.id,
      revision: cause.revision,
    });
    expect(published.status).toBe(200);
    expect(
      await auth.getPublishedCauses(enrolledAdmin.headers(), draft.slug),
    ).toMatchObject([{ zakat_approved_by: { en: "Test scholar" } }]);

    const current = await read();
    const changed = await enrolledAdmin.post("/cause", {
      action: "edit",
      ...draft,
      id: current.id,
      revision: current.revision,
      scholar: null,
      receiptPublicByDefault: false,
    });
    expect(changed.status).toBe(200);
    expect(await read()).toMatchObject({
      zakat_approved_by: null,
      receipt_public_by_default: false,
    });
  });

  it("reverses a recorded transfer once and reports the cancellation on its private trail", async () => {
    const [bank] = await asOwner<{ id: string }>(`
      insert into app.institute_bank_accounts (institute_id, label, bank_name, account_title, account_number)
      select institute_id, '{"en":"Fixture bank"}', 'Bank', 'Institute', '123456'
      from app.institute_domains where domain = 'azeem-lateef.com'
      returning id
    `);
    const [cause] = await auth.getPublishedCauses(
      enrolledAdmin.headers(),
      "test-zakat-cause",
    );
    const email = "fixture-reversal@example.test";
    const recorded = await enrolledAdmin.post("/manual-donation", {
      operation: crypto.randomUUID(),
      bank: bank.id,
      reference: "fixture-reversal-reference",
      date: karachiDate(),
      amount: "1200",
      type: "general",
      cause: cause.id,
      email,
      language: "ur",
      confirmLarge: false,
      confirmSimilar: false,
    });
    expect(recorded.status).toBe(201);
    const receipt = recorded.json.receipt;
    const issued = await enrolledAdmin.post("/donor-link", {
      action: "issue",
      receipt,
      email,
      language: "ur",
      confirm: true,
    });
    expect(issued.status).toBe(201);
    const token = new URL(issued.json.link).hash.slice(1);

    const lookup = { action: "lookup", receipt };
    expect(
      (await new Browser().post("/donation-reversal", lookup)).status,
    ).toBe(403);
    const before = await enrolledAdmin.post("/donation-reversal", lookup);
    expect(before.json.transfer).toMatchObject({
      receipt_number: receipt,
      amount_paisa: "120000",
      status: "recorded",
      has_spending: false,
    });
    expect(JSON.stringify(before.json)).not.toContain(email);
    const reversal = {
      action: "reverse",
      receipt,
      category: "other",
      note: "Duplicate import from an old spreadsheet",
    };
    expect(
      (await enrolledAdmin.post("/donation-reversal", reversal)).status,
    ).toBe(400);
    expect(
      (
        await enrolledAdmin.post("/donation-reversal", {
          ...reversal,
          confirm: true,
          note: "",
        })
      ).status,
    ).toBe(400);
    const changed = await enrolledAdmin.post("/donation-reversal", {
      ...reversal,
      confirm: true,
    });
    expect(changed.status).toBe(200);
    expect(changed.json).toMatchObject({
      code: "reversed",
      transfer: {
        receipt_number: receipt,
        amount_paisa: "120000",
        status: "reversed",
        reversal_reason: "other",
      },
    });
    expect(JSON.stringify(changed.json)).not.toContain(reversal.note);
    const retry = await enrolledAdmin.post("/donation-reversal", {
      ...reversal,
      confirm: true,
    });
    expect(retry.json.code).toBe("already_reversed");

    const trail = await new Browser().post("/donor-trail", { token });
    expect(trail.status).toBe(200);
    expect(trail.json.donations).toMatchObject([
      {
        receipt_number: receipt,
        status: "reversed",
        reversal_reason: "other",
        events: [],
        cause_title: cause.title,
      },
    ]);
    expect(JSON.stringify(trail.json)).not.toContain(reversal.note);
    expect(
      (await auth.getPublishedCauses(enrolledAdmin.headers(), cause.slug))[0]
        .raised_paisa,
    ).toBe("0");
    const audit = await asOwner(
      `
      select a.reason from app.audit_log a join app.donations d on a.entity_id = d.id::text
      where d.receipt_number = $1 and a.action = 'donations.reversed'
    `,
      [receipt],
    );
    expect(audit).toEqual([{ reason: reversal.note }]);
  });

  it("closes a bank statement atomically and records other credits in the audit log", async () => {
    const banks = await asOwner<{ id: string; is_active: boolean }>(`
      insert into app.institute_bank_accounts (institute_id, label, bank_name, account_title, account_number, is_active)
      select institute_id, '{"en":"Statement fixture"}', 'Bank', 'Institute', reference, active
      from app.institute_domains cross join (values ('statement-bank', true), ('old-statement-bank', false)) as fixture(reference, active)
      where domain = 'azeem-lateef.com' returning id, is_active
    `);
    const bank = banks.find(({ is_active }) => is_active)!.id;
    const oldBank = banks.find(({ is_active }) => !is_active)!.id;
    const today = karachiDate();
    const period = { bank, from: today, to: today };
    const post = (action: string, extra: object = {}) =>
      enrolledAdmin.post("/bank-reconciliation", {
        action,
        ...period,
        ...extra,
      });
    const workspace = await auth.getStatementWorkspace(enrolledAdmin.headers());
    expect(workspace).toMatchObject({ state: "allowed" });
    if (workspace.state !== "allowed")
      throw new Error("Missing finance access");
    expect(workspace.banks).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: oldBank, is_active: false }),
      ]),
    );
    expect(
      (
        await new Browser().post("/bank-reconciliation", {
          action: "load",
          ...period,
        })
      ).status,
    ).toBe(403);

    const record = async (reference: string, amount: string) => {
      const saved = await enrolledAdmin.post("/manual-donation", {
        operation: crypto.randomUUID(),
        bank,
        reference,
        date: today,
        amount,
        type: "general",
        cause: "",
        email: "",
        language: "en",
        confirmLarge: false,
        confirmSimilar: false,
      });
      expect(saved.status).toBe(201);
      return saved.json.receipt;
    };
    const first = await record("statement private reference 3021", "400");
    const before = await post("load");
    expect(before.json.statement.transfers).toMatchObject([
      { receipt_number: first, reference_tail: "3021", matched: null },
    ]);
    expect(JSON.stringify(before.json)).not.toContain("private reference");
    const firstId = before.json.statement.transfers[0].id;
    const second = await record("statement reference 3022", "500");
    const close = { matched: [firstId], operation: crypto.randomUUID() };
    expect(
      (await post("close", { ...close, review: before.json.statement.review }))
        .status,
    ).toBe(409);

    const snapshot = await post("load");
    const review = snapshot.json.statement.review;
    expect(
      (
        await post("close", {
          ...close,
          review,
          matched: [crypto.randomUUID()],
        })
      ).status,
    ).toBe(400);
    const closed = await post("close", { ...close, review });
    expect(closed.status).toBe(200);
    expect(closed.json.statement.transfers).toMatchObject([
      {
        receipt_number: first,
        matched: true,
        statement_from: today,
        statement_to: today,
      },
      {
        receipt_number: second,
        matched: false,
        statement_from: today,
        statement_to: today,
      },
    ]);
    expect((await post("close", { ...close, review })).json.code).toBe(
      "closed",
    );
    expect(
      (await post("close", { ...close, review, matched: [] })).status,
    ).toBe(400);
    const [summary] = await asOwner<{ changes: Record<string, unknown> }>(
      `
      select changes from app.audit_log where action = 'bank_statement.closed' and entity_id = $1
    `,
      [close.operation],
    );
    expect(summary.changes).toMatchObject({
      matched_count: 1,
      missing_count: 1,
      matched_paisa: "40000",
    });

    const otherCredit = {
      credited: today,
      amount: "۱۲۵٫۵۰",
      note: "Supplier refund fixture",
      operation: crypto.randomUUID(),
    };
    const noted = await post("note", otherCredit);
    expect(noted.json.statement.otherCredits).toMatchObject([
      { credited_on: today, amount_paisa: "12550" },
    ]);
    expect(JSON.stringify(noted.json)).not.toContain(otherCredit.note);
    expect(
      (await post("note", otherCredit)).json.statement.otherCredits,
    ).toHaveLength(1);
    const notes = await asOwner(
      `select reason from app.audit_log where action = 'bank_statement.non_donation' and entity_id = $1`,
      [otherCredit.operation],
    );
    expect(notes).toEqual([{ reason: otherCredit.note }]);
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

describe("donor sign-up, email verification and password reset (P0-E5-T02)", () => {
  const donorEmail = "new.donor@example.test";
  const outbox: string[] = [];
  const info = vi
    .spyOn(console, "info")
    .mockImplementation((line: string) => void outbox.push(line));
  afterAll(() => info.mockRestore());

  async function post(browser: Browser, path: string, body: object) {
    await spreadOverTime();
    return browser.post(path, body);
  }

  function lastLink(kind: "verify-email" | "reset-password") {
    const message = outbox.at(-1) ?? "";
    const match = new RegExp(`${origin}/api/auth/${kind}[^\\s]*`).exec(message);
    return match ? new URL(match[0]) : null;
  }

  async function open(url: URL) {
    const response = await auth.handleAuth(
      new Request(url, { headers: { host: "localhost:3000" } }),
    );
    return response;
  }

  it("creates an active donor with an unverified email and sends a bilingual link", async () => {
    const browser = new Browser();
    const signUp = await post(browser, "/sign-up/email", {
      name: "New Donor",
      email: donorEmail,
      password,
      preferredLanguage: "ur",
    });
    expect(signUp.status).toBe(200);
    expect(signUp.json.token).toBeNull();
    expect(browser.cookies.size).toBe(0);
    const [user] = await asOwner<Record<string, unknown>>(
      `select status, must_change_password, email_verified, username,
         preferred_language, array(select role from app.user_roles r where r.user_id = u.id) as roles
       from app.users u where email = $1`,
      [donorEmail],
    );
    expect(user).toEqual({
      status: "active",
      must_change_password: false,
      email_verified: false,
      username: null,
      preferred_language: "ur",
      roles: ["donor"],
    });
    expect(outbox.at(-1)).toContain("اپنا ای میل پتہ تصدیق کریں");
    expect(outbox.at(-1)).not.toContain(donorEmail);
    expect(lastLink("verify-email")).not.toBeNull();
  });

  it("answers a sign-up for a known email exactly like a new one", async () => {
    const before = outbox.length;
    const again = await post(new Browser(), "/sign-up/email", {
      name: "Someone Else",
      email: "admin@example.test",
      password: "another password 123",
    });
    expect(again.status).toBe(200);
    expect(again.json.token).toBeNull();
    expect(Object.keys(again.json.user).sort()).toEqual(
      Object.keys(
        (
          await post(new Browser(), "/sign-up/email", {
            name: "Fresh",
            email: "fresh.donor@example.test",
            password,
          })
        ).json.user,
      ).sort(),
    );
    expect(outbox.length).toBe(before + 1);
    const roles = await asOwner(
      `select role from app.user_roles r join app.users u on u.id = r.user_id
       where u.email = 'admin@example.test'`,
    );
    expect(roles).toEqual([{ role: "admin" }]);
  });

  it("does not let sign-up choose a username, institute or role", async () => {
    for (const extra of [
      { username: "azeem-s-0001" },
      { instituteId: "00000000-0000-4000-8000-000000000000" },
      { preferredLanguage: "fr" },
    ]) {
      const response = await post(new Browser(), "/sign-up/email", {
        name: "Sneaky",
        email: `sneaky.${Object.keys(extra)[0]}@example.test`,
        password,
        ...extra,
      });
      expect(response.status).toBe(400);
    }
    expect(
      await asOwner(`select from app.users where email like 'sneaky.%'`),
    ).toHaveLength(0);
  });

  it("refuses sign-in until the email is confirmed, and leaves no session behind", async () => {
    const browser = new Browser();
    const blocked = await post(browser, "/sign-in/email", {
      email: donorEmail,
      password,
    });
    expect(blocked.status).toBe(403);
    expect(blocked.json.code).toBe("EMAIL_NOT_VERIFIED");
    expect(browser.cookies.size).toBe(0);
    expect(
      await asOwner(
        `select from identity.sessions s join app.users u on u.id = s.user_id where u.email = $1`,
        [donorEmail],
      ),
    ).toHaveLength(0);
    expect(
      await asOwner(
        `select from app.audit_log a join app.users u on u.id::text = a.entity_id
         where u.email = $1 and a.action = 'auth.signed_in'`,
        [donorEmail],
      ),
    ).toHaveLength(0);
  });

  it("confirms the email through the link, then signs in", async () => {
    await post(new Browser(), "/send-verification-email", {
      email: donorEmail,
    });
    const link = lastLink("verify-email")!;
    const confirmed = await open(link);
    expect(confirmed.status).toBeLessThan(400);
    const [user] = await asOwner<{ email_verified: boolean }>(
      `select email_verified from app.users where email = $1`,
      [donorEmail],
    );
    expect(user.email_verified).toBe(true);

    const browser = new Browser();
    const signIn = await post(browser, "/sign-in/email", {
      email: donorEmail,
      password,
    });
    expect(signIn.status).toBe(200);
    expect((await browser.get("/get-session")).json).toMatchObject({
      user: { email: donorEmail },
    });
    expect(await auth.getAccountAccess(browser.headers())).toEqual({
      state: "allowed",
      name: "New Donor",
      email: donorEmail,
      roles: ["donor"],
      mustChangePassword: false,
    });
  });

  it("resets a password by email and signs out every device", async () => {
    const phone = new Browser();
    const laptop = new Browser();
    for (const device of [phone, laptop])
      await post(device, "/sign-in/email", { email: donorEmail, password });
    expect((await laptop.get("/get-session")).json).not.toBeNull();

    const requested = await post(new Browser(), "/request-password-reset", {
      email: donorEmail,
      redirectTo: "/ur/reset-password",
    });
    expect(requested.status).toBe(200);
    expect(outbox.at(-1)).toContain("اپنا پاس ورڈ دوبارہ ترتیب دیں");
    const link = lastLink("reset-password")!;
    const landing = await open(link);
    expect(landing.status).toBe(302);
    const page = new URL(landing.headers.get("location")!, origin);
    expect(page.pathname).toBe("/ur/reset-password");
    const token = page.searchParams.get("token");
    expect(token).toBeTruthy();

    const newPassword = "a brand new passphrase";
    const reset = await post(new Browser(), "/reset-password", {
      token,
      newPassword,
    });
    expect(reset.status).toBe(200);
    expect((await phone.get("/get-session")).json).toBeNull();
    expect((await laptop.get("/get-session")).json).toBeNull();

    const old = await post(new Browser(), "/sign-in/email", {
      email: donorEmail,
      password,
    });
    expect(old.status).toBe(401);
    const fresh = await post(new Browser(), "/sign-in/email", {
      email: donorEmail,
      password: newPassword,
    });
    expect(fresh.status).toBe(200);
    // The token works once.
    expect(
      (
        await post(new Browser(), "/reset-password", {
          token,
          newPassword: "yet another passphrase",
        })
      ).status,
    ).toBe(400);
  });

  it("answers a reset for an unknown email the same way and sends nothing", async () => {
    const before = outbox.length;
    const response = await post(new Browser(), "/request-password-reset", {
      email: "nobody@example.test",
    });
    expect(response.status).toBe(200);
    expect(outbox.length).toBe(before);
  });
});

describe("student accounts made by staff (P0-E5-T03)", () => {
  async function signedIn(email: string) {
    const browser = new Browser();
    await spreadOverTime();
    await browser.post("/sign-in/email", { email, password });
    return browser;
  }

  let student: { username: string; password: string };

  it("lets a teacher create a student with a generated username and starting password", async () => {
    const teacher = await signedIn("teacher@example.test");
    const year = new Date().getFullYear();
    const first = await teacher.post("/student-account", {
      name: "Ahmed Raza",
      classId: hifzClass,
    });
    expect(first.status).toBe(201);
    expect(first.json.username).toBe(`maa-${year}-0001`);
    expect(first.json.password).toMatch(/^[a-km-np-z2-9]{10}$/);
    const second = await teacher.post("/student-account", {
      name: "Bilal Khan",
      classId: hifzClass,
      password: "chosen by teacher",
    });
    expect(second.json).toEqual({
      username: `maa-${year}-0002`,
      password: "chosen by teacher",
    });
    student = first.json;

    const [row] = await asOwner<Record<string, unknown>>(
      `select u.status, u.must_change_password, u.email,
         array(select role from app.user_roles r where r.user_id = u.id) as roles,
         (select actor_user_id from app.audit_log a
          where a.entity_id = u.id::text and a.action = 'users.insert') as created_by,
         (select count(*)::int from app.persona_links l
          join app.class_members m on m.user_id = l.user_id and m.class_id = $2
          where l.user_id = u.id) as personas
       from app.users u where username = $1`,
      [student.username, hifzClass],
    );
    expect(row).toEqual({
      status: "active",
      must_change_password: true,
      email: null,
      roles: ["student"],
      created_by: staff.teacher,
      personas: 1,
    });
  });

  it("refuses student creation to editors, donors, students and visitors", async () => {
    for (const email of ["editor@example.test", "donor@example.test"]) {
      const browser = await signedIn(email);
      expect(
        (
          await browser.post("/student-account", {
            name: "Someone",
            classId: hifzClass,
          })
        ).status,
      ).toBe(403);
    }
    expect(
      (
        await new Browser().post("/student-account", {
          name: "Someone",
          classId: hifzClass,
        })
      ).status,
    ).toBe(403);
    const pupil = new Browser();
    await spreadOverTime();
    await pupil.post("/sign-in/username", {
      username: student.username,
      password: student.password,
    });
    expect(
      (
        await pupil.post("/student-account", {
          name: "Someone",
          classId: hifzClass,
        })
      ).status,
    ).toBe(403);
    expect(
      await asOwner(`select from app.users where full_name = 'Someone'`),
    ).toHaveLength(0);
  });

  it("signs a student in by username and asks for a new password first", async () => {
    const pupil = new Browser();
    await spreadOverTime();
    const signIn = await pupil.post("/sign-in/username", {
      username: student.username.toUpperCase(),
      password: student.password,
    });
    expect(signIn.status).toBe(200);
    expect((await pupil.get("/get-session")).json.user).toMatchObject({
      username: student.username,
      mustChangePassword: true,
    });
    expect(await pupil.access()).toEqual({ state: "denied" });
  });

  it("replaces the starting password once and signs out other devices", async () => {
    const phone = new Browser();
    const tablet = new Browser();
    for (const device of [phone, tablet]) {
      await spreadOverTime();
      await device.post("/sign-in/username", {
        username: student.username,
        password: student.password,
      });
    }
    const newPassword = "my own secret";
    expect(
      (
        await phone.post("/first-password", {
          currentPassword: "wrong password",
          newPassword,
        })
      ).status,
    ).toBe(400);
    const changed = await phone.post("/first-password", {
      currentPassword: student.password,
      newPassword,
    });
    expect(changed.status).toBe(200);
    expect((await tablet.get("/get-session")).json).toBeNull();
    expect((await phone.get("/get-session")).json.user).toMatchObject({
      mustChangePassword: false,
    });
    expect(
      (
        await phone.post("/first-password", {
          currentPassword: newPassword,
          newPassword: "and another one",
        })
      ).status,
    ).toBe(403);

    await spreadOverTime();
    const old = await new Browser().post("/sign-in/username", {
      username: student.username,
      password: student.password,
    });
    expect(old.status).toBe(401);
    await spreadOverTime();
    const fresh = await new Browser().post("/sign-in/username", {
      username: student.username,
      password: newPassword,
    });
    expect(fresh.status).toBe(200);
  });

  it("never sends a student a reset email", async () => {
    await asOwner(
      `update app.users set email = 'pupil@example.test' where username = $1`,
      [student.username],
    );
    const lines: string[] = [];
    const info = vi
      .spyOn(console, "info")
      .mockImplementation((line: string) => void lines.push(line));
    try {
      const response = await new Browser().post("/request-password-reset", {
        email: "pupil@example.test",
      });
      expect(response.status).toBe(200);
      expect(lines).toEqual([]);
    } finally {
      info.mockRestore();
    }
  });
});
