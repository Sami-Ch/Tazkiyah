import { sql } from "drizzle-orm";
import {
  bigint,
  boolean,
  foreignKey,
  index,
  integer,
  pgPolicy,
  pgSchema,
  primaryKey,
  text,
  timestamp,
  unique,
  uuid,
} from "drizzle-orm/pg-core";
import { institutes, users } from "./schema";

export const identity = pgSchema("identity");

const identityId = () => uuid().defaultRandom().primaryKey();
const instituteId = () =>
  uuid("institute_id")
    .notNull()
    .default(sql`app.current_institute_id()`)
    .references(() => institutes.id);
const instant = (name: string) => timestamp(name, { withTimezone: true });
const createdAt = () => instant("created_at").notNull().defaultNow();
const updatedAt = () => instant("updated_at").notNull().defaultNow();

function authPolicies() {
  const tenant = sql`institute_id = (select app.current_institute_id())`;
  return [
    pgPolicy("iso", {
      as: "restrictive",
      to: "tazkiyah_auth",
      using: tenant,
      withCheck: tenant,
    }),
    pgPolicy("auth_access", {
      to: "tazkiyah_auth",
      using: sql`true`,
      withCheck: sql`true`,
    }),
  ];
}

export const authSessions = identity
  .table(
    "sessions",
    {
      id: identityId(),
      instituteId: instituteId(),
      userId: uuid("user_id").notNull(),
      token: text().notNull(),
      twoFactorVerifiedAt: instant("two_factor_verified_at"),
      expiresAt: instant("expires_at").notNull(),
      createdAt: createdAt(),
      updatedAt: updatedAt(),
      ipAddress: text("ip_address"),
      userAgent: text("user_agent"),
    },
    (t) => [
      unique().on(t.instituteId, t.token),
      index().on(t.instituteId, t.userId),
      foreignKey({
        columns: [t.instituteId, t.userId],
        foreignColumns: [users.instituteId, users.id],
      }).onDelete("cascade"),
      ...authPolicies(),
    ],
  )
  .enableRLS();

export const authAccounts = identity
  .table(
    "accounts",
    {
      id: identityId(),
      instituteId: instituteId(),
      userId: uuid("user_id").notNull(),
      providerId: text("provider_id").notNull(),
      accountId: text("account_id").notNull(),
      password: text(),
      accessToken: text("access_token"),
      refreshToken: text("refresh_token"),
      idToken: text("id_token"),
      accessTokenExpiresAt: instant("access_token_expires_at"),
      refreshTokenExpiresAt: instant("refresh_token_expires_at"),
      scope: text(),
      createdAt: createdAt(),
      updatedAt: updatedAt(),
    },
    (t) => [
      unique().on(t.instituteId, t.providerId, t.accountId),
      index().on(t.instituteId, t.userId),
      foreignKey({
        columns: [t.instituteId, t.userId],
        foreignColumns: [users.instituteId, users.id],
      }).onDelete("cascade"),
      ...authPolicies(),
    ],
  )
  .enableRLS();

export const authVerification = identity
  .table(
    "verification",
    {
      id: identityId(),
      instituteId: instituteId(),
      identifier: text().notNull(),
      value: text().notNull(),
      expiresAt: instant("expires_at").notNull(),
      createdAt: createdAt(),
      updatedAt: updatedAt(),
    },
    (t) => [index().on(t.instituteId, t.identifier), ...authPolicies()],
  )
  .enableRLS();

export const authTwoFactor = identity
  .table(
    "two_factor",
    {
      id: identityId(),
      instituteId: instituteId(),
      userId: uuid("user_id").notNull(),
      secret: text().notNull(),
      backupCodes: text("backup_codes").notNull(),
      verified: boolean().notNull().default(true),
      failedVerificationCount: integer("failed_verification_count")
        .notNull()
        .default(0),
      lockedUntil: instant("locked_until"),
    },
    (t) => [
      unique().on(t.instituteId, t.userId),
      foreignKey({
        columns: [t.instituteId, t.userId],
        foreignColumns: [users.instituteId, users.id],
      }).onDelete("cascade"),
      ...authPolicies(),
    ],
  )
  .enableRLS();

export const authRateLimit = identity
  .table(
    "rate_limit",
    {
      id: identityId(),
      instituteId: instituteId(),
      key: text().notNull(),
      count: integer().notNull(),
      lastRequest: bigint("last_request", { mode: "number" }).notNull(),
    },
    (t) => [
      unique().on(t.instituteId, t.key),
      index().on(t.instituteId, t.lastRequest),
      ...authPolicies(),
    ],
  )
  .enableRLS();

export const staffInvitations = identity
  .table(
    "staff_invitations",
    {
      instituteId: instituteId(),
      userId: uuid("user_id").notNull(),
      tokenHash: text("token_hash").notNull(),
      expiresAt: instant("expires_at").notNull(),
    },
    (t) => [
      primaryKey({ columns: [t.instituteId, t.userId] }),
      unique().on(t.instituteId, t.tokenHash),
      foreignKey({
        columns: [t.instituteId, t.userId],
        foreignColumns: [users.instituteId, users.id],
      }).onDelete("cascade"),
      ...authPolicies(),
    ],
  )
  .enableRLS();
