import {
  customType,
  pgSchema,
  unique,
  pgPolicy,
  check,
  uuid,
  text,
  timestamp,
  uniqueIndex,
  foreignKey,
  boolean,
  integer,
  jsonb,
  char,
  smallint,
  index,
  date,
  bigint,
  numeric,
  primaryKey,
  type AnyPgColumn,
  type PgTableExtraConfigValue,
} from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";

const localizedText = customType<{
  data: Record<string, string>;
  driverData: string;
}>({
  dataType: () => "app.localized_text",
  toDriver: (value) => JSON.stringify(value),
});

export const app = pgSchema("app");
export const publicApi = pgSchema("public_api");

export const institutes = app
  .table(
    "institutes",
    {
      id: uuid().defaultRandom().primaryKey().notNull(),
      slug: text().notNull(),
      kind: text().default("institute").notNull(),
      status: text().default("active").notNull(),
      createdAt: timestamp("created_at", { withTimezone: true, mode: "string" })
        .defaultNow()
        .notNull(),
    },
    (table) => [
      unique("institutes_slug_key").on(table.slug),
      pgPolicy("iso", {
        as: "restrictive",
        for: "all",
        to: ["tazkiyah_app"],
        using: sql`(id = app.current_institute_id())`,
        withCheck: sql`(id = app.current_institute_id())`,
      }),
      check(
        "institutes_slug_check",
        sql`slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text`,
      ),
      check(
        "institutes_kind_check",
        sql`kind = ANY (ARRAY['institute'::text, 'platform_fund'::text])`,
      ),
      check(
        "institutes_status_check",
        sql`status = ANY (ARRAY['active'::text, 'suspended'::text])`,
      ),
    ],
  )
  .enableRLS();

export const instituteDomains = app
  .table(
    "institute_domains",
    {
      id: uuid().defaultRandom().primaryKey().notNull(),
      instituteId: uuid("institute_id").notNull(),
      domain: text().notNull(),
      isPrimary: boolean("is_primary").default(false).notNull(),
    },
    (table) => [
      uniqueIndex("institute_domains_one_primary")
        .on(table.instituteId)
        .where(sql`is_primary`),
      foreignKey({
        columns: [table.instituteId],
        foreignColumns: [institutes.id],
        name: "institute_domains_institute_id_fkey",
      }),
      unique("institute_domains_domain_key").on(table.domain),
      unique("institute_domains_institute_id_id_key").on(
        table.instituteId,
        table.id,
      ),
      pgPolicy("iso", {
        as: "restrictive",
        for: "all",
        to: ["tazkiyah_app"],
        using: sql`(institute_id = app.current_institute_id())`,
        withCheck: sql`(institute_id = app.current_institute_id())`,
      }),
      check(
        "institute_domains_domain_check",
        sql`(length(domain) <= 253) AND (domain !~~ 'www.%'::text) AND (domain ~ '^[a-z0-9]([a-z0-9-]*[a-z0-9])?([.][a-z0-9]([a-z0-9-]*[a-z0-9])?)*$'::text)`,
      ),
    ],
  )
  .enableRLS();

export const instituteBankAccounts = app
  .table(
    "institute_bank_accounts",
    {
      id: uuid().defaultRandom().primaryKey().notNull(),
      instituteId: uuid("institute_id").notNull(),
      label: localizedText("label").notNull(),
      bankName: text("bank_name").notNull(),
      accountTitle: text("account_title").notNull(),
      accountNumber: text("account_number"),
      iban: text(),
      branch: text(),
      forDonationTypes: text("for_donation_types")
        .array()
        .default(sql`ARRAY['zakat', 'sadaqah', 'general']::text[]`)
        .notNull(),
      isActive: boolean("is_active").default(true).notNull(),
      showOnDonate: boolean("show_on_donate").default(false).notNull(),
      displayOrder: integer("display_order").default(0).notNull(),
    },
    (table) => [
      foreignKey({
        columns: [table.instituteId],
        foreignColumns: [institutes.id],
        name: "institute_bank_accounts_institute_id_fkey",
      }),
      unique("institute_bank_accounts_institute_id_id_key").on(
        table.instituteId,
        table.id,
      ),
      pgPolicy("iso", {
        as: "restrictive",
        for: "all",
        to: ["tazkiyah_app"],
        using: sql`(institute_id = app.current_institute_id())`,
        withCheck: sql`(institute_id = app.current_institute_id())`,
      }),
      pgPolicy("bank_accounts_admin_read", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`(select app.has_role('admin'))`,
      }),
      check(
        "institute_bank_accounts_for_donation_types_check",
        sql`(cardinality(for_donation_types) > 0) AND (array_position(for_donation_types, NULL::text) IS NULL) AND (for_donation_types <@ ARRAY['zakat'::text, 'sadaqah'::text, 'general'::text])`,
      ),
      check(
        "institute_bank_accounts_check",
        sql`(NULLIF(btrim(account_number), ''::text) IS NOT NULL) OR (NULLIF(btrim(iban), ''::text) IS NOT NULL)`,
      ),
    ],
  )
  .enableRLS();

export const instituteSettings = app
  .table(
    "institute_settings",
    {
      instituteId: uuid("institute_id").primaryKey().notNull(),
      name: localizedText("name").notNull(),
      shortName: localizedText("short_name"),
      parentBody: localizedText("parent_body"),
      theme: jsonb().notNull(),
      languages: text()
        .array()
        .default(sql`ARRAY['ur', 'en']::text[]`)
        .notNull(),
      defaultLanguage: text("default_language").default("en").notNull(),
      timezone: text().default("Asia/Karachi").notNull(),
      baseCurrency: char("base_currency", { length: 3 })
        .default("PKR")
        .notNull(),
      address: localizedText("address").notNull(),
      contact: jsonb().default({}).notNull(),
      foundedYear: smallint("founded_year"),
      enabledModules: text("enabled_modules")
        .array()
        .default(sql`'{}'::text[]`)
        .notNull(),
      receiptPrefix: text("receipt_prefix").notNull(),
      communityEnabled: boolean("community_enabled").default(false).notNull(),
      updatedAt: timestamp("updated_at", { withTimezone: true, mode: "string" })
        .defaultNow()
        .notNull(),
      principalUserId: uuid("principal_user_id"),
      updatedBy: uuid("updated_by"),
      logoMediaId: uuid("logo_media_id"),
    },
    (table) => [
      index("institute_settings_principal_user").on(
        table.instituteId,
        table.principalUserId,
      ),
      index("institute_settings_updated_by").on(
        table.instituteId,
        table.updatedBy,
      ),
      index("institute_settings_logo_media").on(
        table.instituteId,
        table.logoMediaId,
      ),
      foreignKey({
        columns: [table.instituteId],
        foreignColumns: [institutes.id],
        name: "institute_settings_institute_id_fkey",
      }),
      foreignKey({
        columns: [table.instituteId, table.principalUserId],
        foreignColumns: [users.instituteId, users.id],
        name: "institute_settings_institute_id_principal_user_id_fkey",
      }),
      foreignKey({
        columns: [table.instituteId, table.updatedBy],
        foreignColumns: [users.instituteId, users.id],
        name: "institute_settings_institute_id_updated_by_fkey",
      }),
      foreignKey({
        columns: [table.instituteId, table.logoMediaId],
        foreignColumns: [mediaAssets.instituteId, mediaAssets.id],
        name: "institute_settings_institute_id_logo_media_id_fkey",
      }),
      pgPolicy("iso", {
        as: "restrictive",
        for: "all",
        to: ["tazkiyah_app"],
        using: sql`(institute_id = app.current_institute_id())`,
        withCheck: sql`(institute_id = app.current_institute_id())`,
      }),
      pgPolicy("settings_admin_read", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`(select app.has_role('admin'))`,
      }),
      pgPolicy("settings_admin_update", {
        as: "permissive",
        for: "update",
        to: ["tazkiyah_app"],
        using: sql`(select app.has_role('admin'))`,
        withCheck: sql`(select app.has_role('admin'))`,
      }),
      check("institute_settings_theme_check", sql`app.valid_theme(theme)`),
      check(
        "institute_settings_languages_check",
        sql`array_position(languages, NULL::text) IS NULL`,
      ),
      check(
        "institute_settings_check",
        sql`default_language = ANY (languages)`,
      ),
      check(
        "institute_settings_base_currency_check",
        sql`base_currency ~ '^[A-Z]{3}$'::text`,
      ),
      check(
        "institute_settings_contact_check",
        sql`jsonb_typeof(contact) = 'object'::text`,
      ),
      check(
        "institute_settings_enabled_modules_check",
        sql`(array_position(enabled_modules, NULL::text) IS NULL) AND (enabled_modules <@ ARRAY['student_hub'::text, 'teacher_hub'::text, 'new_projects'::text])`,
      ),
      check(
        "institute_settings_receipt_prefix_check",
        sql`receipt_prefix ~ '^[A-Z0-9]+$'::text`,
      ),
      check(
        "institute_settings_community_enabled_check",
        sql`NOT community_enabled`,
      ),
    ],
  )
  .enableRLS();

export const users = app
  .table(
    "users",
    {
      id: uuid().defaultRandom().primaryKey().notNull(),
      instituteId: uuid("institute_id").notNull(),
      email: text(),
      emailVerified: boolean("email_verified").notNull().default(false),
      authImage: text("auth_image"),
      twoFactorEnabled: boolean("two_factor_enabled").notNull().default(false),
      updatedAt: timestamp("updated_at", { withTimezone: true })
        .notNull()
        .defaultNow(),
      username: text(),
      fullName: text("full_name").notNull(),
      publicName: text("public_name"),
      publicBio: localizedText("public_bio"),
      dateOfBirth: date("date_of_birth"),
      isOrphan: boolean("is_orphan").default(false).notNull(),
      preferredLanguage: text("preferred_language").default("en").notNull(),
      status: text().default("invited").notNull(),
      leftAt: date("left_at"),
      mustChangePassword: boolean("must_change_password")
        .default(true)
        .notNull(),
      onboardedAt: timestamp("onboarded_at", {
        withTimezone: true,
        mode: "string",
      }),
      lastLoginAt: timestamp("last_login_at", {
        withTimezone: true,
        mode: "string",
      }),
      createdAt: timestamp("created_at", { withTimezone: true })
        .defaultNow()
        .notNull(),
      photoMediaId: uuid("photo_media_id"),
    },
    (table): PgTableExtraConfigValue[] => [
      uniqueIndex("users_institute_email").on(
        table.instituteId,
        sql`lower(email)`,
      ),
      uniqueIndex("users_institute_username").on(
        table.instituteId,
        sql`lower(username)`,
      ),
      // Better Auth looks users up by the stored, already lower-case value,
      // which the lower() indexes above cannot serve (P0-E2-T19).
      index("users_email_lookup").on(table.instituteId, table.email),
      index("users_username_lookup").on(table.instituteId, table.username),
      index("users_photo_media").on(table.instituteId, table.photoMediaId),
      foreignKey({
        columns: [table.instituteId],
        foreignColumns: [institutes.id],
        name: "users_institute_id_fkey",
      }),
      foreignKey({
        columns: [table.instituteId, table.photoMediaId],
        foreignColumns: [mediaAssets.instituteId, mediaAssets.id],
        name: "users_institute_id_photo_media_id_fkey",
      }),
      unique("users_institute_id_id_key").on(table.instituteId, table.id),
      pgPolicy("iso", {
        as: "restrictive",
        for: "all",
        to: ["tazkiyah_app"],
        using: sql`(institute_id = ( SELECT app.current_institute_id() AS current_institute_id))`,
        withCheck: sql`(institute_id = ( SELECT app.current_institute_id() AS current_institute_id))`,
      }),
      pgPolicy("auth_iso", {
        as: "restrictive",
        to: "tazkiyah_auth",
        using: sql`institute_id = (select app.current_institute_id())`,
        withCheck: sql`institute_id = (select app.current_institute_id())`,
      }),
      pgPolicy("auth_user_read", {
        for: "select",
        to: "tazkiyah_auth",
        using: sql`status in ('active', 'left')`,
      }),
      pgPolicy("auth_user_update", {
        for: "update",
        to: "tazkiyah_auth",
        using: sql`status in ('active', 'left')`,
        withCheck: sql`status in ('active', 'left')`,
      }),
      pgPolicy("user_read", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`(id = (select app.current_user_id()) and status in ('active', 'left'))
  or (select app.has_role('admin'))`,
      }),
      // A student's teachers see the real student behind the persona
      // (04 §6.4, REQ-TCH-006).
      pgPolicy("users_teacher_read", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`app.is_teacher_of(id)`,
      }),
      pgPolicy("own_language", {
        as: "permissive",
        for: "update",
        to: ["tazkiyah_app"],
        using: sql`id = (select app.current_user_id()) and status in ('active', 'left')`,
        withCheck: sql`id = (select app.current_user_id()) and status in ('active', 'left')`,
      }),
      check(
        "users_email_check",
        sql`(email = btrim(email)) AND (email <> ''::text)`,
      ),
      check(
        "users_username_check",
        sql`(username = btrim(username)) AND (username <> ''::text)`,
      ),
      check("users_full_name_check", sql`full_name ~ '[^[:space:]]'::text`),
      check(
        "users_preferred_language_check",
        sql`preferred_language = ANY (ARRAY['en'::text, 'ur'::text])`,
      ),
      check(
        "users_status_check",
        sql`status = ANY (ARRAY['invited'::text, 'active'::text, 'left'::text, 'suspended'::text])`,
      ),
      check("users_check", sql`(email IS NOT NULL) OR (username IS NOT NULL)`),
    ],
  )
  .enableRLS();

export const mediaAssets = app
  .table(
    "media_assets",
    {
      id: uuid().defaultRandom().primaryKey().notNull(),
      instituteId: uuid("institute_id").notNull(),
      kind: text().notNull(),
      purpose: text().notNull(),
      visibility: text().default("private").notNull(),
      storageKey: text("storage_key"),
      youtubeId: text("youtube_id"),
      mimeType: text("mime_type"),
      bytes: integer(),
      width: integer(),
      height: integer(),
      durationS: integer("duration_s"),
      pageCount: integer("page_count"),
      variants: jsonb().default({}).notNull(),
      altText: localizedText("alt_text"),
      showsFace: boolean("shows_face").default(false).notNull(),
      uploadedBy: uuid("uploaded_by"),
      status: text().default("pending").notNull(),
      createdAt: timestamp("created_at", { withTimezone: true, mode: "string" })
        .defaultNow()
        .notNull(),
      deletedAt: timestamp("deleted_at", {
        withTimezone: true,
        mode: "string",
      }),
    },
    (table): PgTableExtraConfigValue[] => [
      index("media_assets_uploaded_by").on(table.instituteId, table.uploadedBy),
      foreignKey({
        columns: [table.instituteId],
        foreignColumns: [institutes.id],
        name: "media_assets_institute_id_fkey",
      }),
      foreignKey({
        columns: [table.instituteId, table.uploadedBy],
        foreignColumns: [users.instituteId, users.id],
        name: "media_assets_institute_id_uploaded_by_fkey",
      }),
      unique("media_assets_storage_key_key").on(table.storageKey),
      unique("media_assets_institute_id_id_key").on(
        table.instituteId,
        table.id,
      ),
      pgPolicy("iso", {
        as: "restrictive",
        for: "all",
        to: ["tazkiyah_app"],
        using: sql`(institute_id = ( SELECT app.current_institute_id() AS current_institute_id))`,
        withCheck: sql`(institute_id = ( SELECT app.current_institute_id() AS current_institute_id))`,
      }),
      pgPolicy("media_read", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`(select app.has_role('admin')) or (
  uploaded_by = (select app.current_user_id())
  and (select app.is_member() or app.has_role('donor'))
)`,
      }),
      check(
        "media_assets_kind_check",
        sql`kind = ANY (ARRAY['image'::text, 'audio'::text, 'video'::text, 'slides'::text, 'document'::text, 'youtube'::text])`,
      ),
      check(
        "media_assets_purpose_check",
        sql`purpose = ANY (ARRAY['logo'::text, 'cover'::text, 'post'::text, 'avatar'::text, 'donor_photo'::text, 'staff_photo'::text, 'receipt'::text, 'consent_form'::text, 'sponsorship_update'::text])`,
      ),
      check(
        "media_assets_visibility_check",
        sql`visibility = ANY (ARRAY['public'::text, 'private'::text])`,
      ),
      check(
        "media_assets_check",
        sql`starts_with(storage_key, institute_id::text || '/')`,
      ),
      check(
        "media_assets_youtube_id_check",
        sql`youtube_id ~ '^[A-Za-z0-9_-]{11}$'::text`,
      ),
      check(
        "media_assets_check1",
        sql`(bytes > 0) AND (bytes <=
CASE
    WHEN (purpose = 'avatar'::text) THEN 60000
    WHEN (kind = 'image'::text) THEN 600000
    WHEN (kind = ANY (ARRAY['audio'::text, 'slides'::text])) THEN 10000000
    WHEN (kind = 'document'::text) THEN 5000000
    WHEN (kind = 'video'::text) THEN 25000000
    ELSE 0
END)`,
      ),
      check("media_assets_width_check", sql`width > 0`),
      check("media_assets_height_check", sql`height > 0`),
      check(
        "media_assets_check2",
        sql`(duration_s > 0) AND ((kind <> 'video'::text) OR (duration_s <= 90))`,
      ),
      check(
        "media_assets_check3",
        sql`(page_count > 0) AND ((kind <> 'slides'::text) OR (page_count <= 60))`,
      ),
      check(
        "media_assets_check4",
        sql`app.valid_media_variants(institute_id, variants)`,
      ),
      check(
        "media_assets_status_check",
        sql`status = ANY (ARRAY['pending'::text, 'ready'::text, 'rejected'::text, 'deleted'::text])`,
      ),
      check(
        "media_assets_check5",
        sql`((kind = 'youtube'::text) AND (youtube_id IS NOT NULL) AND (storage_key IS NULL) AND (mime_type IS NULL) AND (bytes IS NULL)) OR ((kind <> 'youtube'::text) AND (storage_key IS NOT NULL) AND (mime_type IS NOT NULL) AND (bytes IS NOT NULL) AND (youtube_id IS NULL))`,
      ),
      check(
        "media_assets_check6",
        sql`(kind <> 'video'::text) OR (status <> 'ready'::text) OR (duration_s IS NOT NULL)`,
      ),
      check(
        "media_assets_check7",
        sql`(kind <> 'slides'::text) OR (status <> 'ready'::text) OR (page_count IS NOT NULL)`,
      ),
      check(
        "media_assets_check8",
        sql`(status = 'deleted'::text) = (deleted_at IS NOT NULL)`,
      ),
      check(
        "media_assets_check9",
        sql`(purpose <> 'consent_form'::text) OR (visibility = 'private'::text)`,
      ),
    ],
  )
  .enableRLS();

export const sitePageDrafts = app
  .table(
    "site_page_drafts",
    {
      id: uuid().defaultRandom().primaryKey().notNull(),
      instituteId: uuid("institute_id")
        .notNull()
        .references(() => institutes.id),
      slug: text().notNull(),
      title: localizedText("title").notNull(),
      body: localizedText("body").notNull(),
      facts: jsonb(),
      revision: uuid().defaultRandom().notNull(),
      pending: boolean().default(true).notNull(),
    },
    (table) => [
      check(
        "site_page_drafts_facts_check",
        sql`facts is null or (slug = 'home' and app.valid_home_facts(facts))`,
      ),
      unique().on(table.instituteId, table.id),
      unique().on(table.instituteId, table.slug),
      check(
        "site_page_drafts_slug_check",
        sql`slug in ('home', 'about', 'facilities', 'daily-life')`,
      ),
      pgPolicy("iso", {
        as: "restrictive",
        for: "all",
        to: ["tazkiyah_app"],
        using: sql`institute_id = (select app.current_institute_id())`,
        withCheck: sql`institute_id = (select app.current_institute_id())`,
      }),
    ],
  )
  .enableRLS();

export const sitePages = app
  .table(
    "site_pages",
    {
      id: uuid().defaultRandom().primaryKey().notNull(),
      instituteId: uuid("institute_id").notNull(),
      slug: text().notNull(),
      title: localizedText("title").notNull(),
      body: localizedText("body").notNull(),
      facts: jsonb(),
      coverMediaId: uuid("cover_media_id"),
      status: text().default("draft").notNull(),
      publishedAt: timestamp("published_at", {
        withTimezone: true,
        mode: "string",
      }),
      updatedAt: timestamp("updated_at", { withTimezone: true, mode: "string" })
        .defaultNow()
        .notNull(),
    },
    (table) => [
      check(
        "site_pages_facts_check",
        sql`facts is null or (slug = 'home' and app.valid_home_facts(facts))`,
      ),
      index("site_pages_cover_media").on(table.instituteId, table.coverMediaId),
      foreignKey({
        columns: [table.instituteId],
        foreignColumns: [institutes.id],
        name: "site_pages_institute_id_fkey",
      }),
      foreignKey({
        columns: [table.instituteId, table.coverMediaId],
        foreignColumns: [mediaAssets.instituteId, mediaAssets.id],
        name: "site_pages_institute_id_cover_media_id_fkey",
      }),
      unique("site_pages_institute_id_id_key").on(table.instituteId, table.id),
      unique("site_pages_institute_id_slug_key").on(
        table.instituteId,
        table.slug,
      ),
      pgPolicy("iso", {
        as: "restrictive",
        for: "all",
        to: ["tazkiyah_app"],
        using: sql`(institute_id = ( SELECT app.current_institute_id() AS current_institute_id))`,
        withCheck: sql`(institute_id = ( SELECT app.current_institute_id() AS current_institute_id))`,
      }),
      pgPolicy("staff_page_read", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`(select app.has_role('admin') or app.has_role('editor'))`,
      }),
      pgPolicy("staff_page_insert", {
        as: "permissive",
        for: "insert",
        to: ["tazkiyah_app"],
        withCheck: sql`(select app.has_role('admin') or app.has_role('editor'))`,
      }),
      pgPolicy("staff_page_update", {
        as: "permissive",
        for: "update",
        to: ["tazkiyah_app"],
        using: sql`(select app.has_role('admin') or app.has_role('editor'))`,
        withCheck: sql`(select app.has_role('admin') or app.has_role('editor'))`,
      }),
      check(
        "site_pages_slug_check",
        sql`slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text`,
      ),
      check(
        "site_pages_status_check",
        sql`status = ANY (ARRAY['draft'::text, 'published'::text, 'archived'::text])`,
      ),
      check(
        "site_pages_check",
        sql`(status <> 'published'::text) OR (published_at IS NOT NULL)`,
      ),
    ],
  )
  .enableRLS();

export const auditLog = app
  .table(
    "audit_log",
    {
      id: bigint({ mode: "bigint" }).primaryKey().generatedAlwaysAsIdentity(),
      instituteId: uuid("institute_id").notNull(),
      occurredAt: timestamp("occurred_at", {
        withTimezone: true,
        mode: "string",
      })
        .defaultNow()
        .notNull(),
      actorUserId: uuid("actor_user_id"),
      actorKind: text("actor_kind").notNull(),
      actorRoles: text("actor_roles")
        .array()
        .default(sql`'{}'::text[]`)
        .notNull(),
      action: text().notNull(),
      entityTable: text("entity_table").notNull(),
      entityId: text("entity_id").notNull(),
      changes: jsonb().default({}).notNull(),
      reason: text(),
      requestId: text("request_id"),
    },
    (table) => [
      // 04 §13.1: the admin filters by time, actor and record (P1-E5-T40).
      index("audit_log_actor").on(
        table.instituteId,
        table.actorUserId,
        table.occurredAt.desc(),
      ),
      index("audit_log_entity").on(
        table.instituteId,
        table.entityTable,
        table.entityId,
      ),
      index("audit_log_institute_time").on(
        table.instituteId,
        table.occurredAt.desc().nullsFirst(),
      ),
      foreignKey({
        columns: [table.instituteId],
        foreignColumns: [institutes.id],
        name: "audit_log_institute_id_fkey",
      }),
      foreignKey({
        columns: [table.instituteId, table.actorUserId],
        foreignColumns: [users.instituteId, users.id],
        name: "audit_log_institute_id_actor_user_id_fkey",
      }),
      unique("audit_log_institute_id_id_key").on(table.instituteId, table.id),
      pgPolicy("iso", {
        as: "restrictive",
        for: "all",
        to: ["tazkiyah_app"],
        using: sql`(institute_id = ( SELECT app.current_institute_id() AS current_institute_id))`,
        withCheck: sql`(institute_id = ( SELECT app.current_institute_id() AS current_institute_id))`,
      }),
      pgPolicy("audit_admin_read", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`(select app.has_role('admin'))`,
      }),
      check(
        "audit_log_actor_kind_check",
        sql`actor_kind = ANY (ARRAY['user'::text, 'job'::text, 'guest_token'::text, 'system'::text])`,
      ),
      check(
        "audit_log_changes_check",
        sql`jsonb_typeof(changes) = 'object'::text`,
      ),
    ],
  )
  .enableRLS();

export const userRoles = app
  .table(
    "user_roles",
    {
      instituteId: uuid("institute_id").notNull(),
      userId: uuid("user_id").notNull(),
      role: text().notNull(),
      canWidenScope: boolean("can_widen_scope").default(false).notNull(),
      grantedBy: uuid("granted_by"),
      createdAt: timestamp("created_at", { withTimezone: true, mode: "string" })
        .defaultNow()
        .notNull(),
    },
    (table) => [
      index("user_roles_granted_by").on(table.instituteId, table.grantedBy),
      foreignKey({
        columns: [table.instituteId, table.userId],
        foreignColumns: [users.instituteId, users.id],
        name: "user_roles_institute_id_user_id_fkey",
      }),
      foreignKey({
        columns: [table.instituteId, table.grantedBy],
        foreignColumns: [users.instituteId, users.id],
        name: "user_roles_institute_id_granted_by_fkey",
      }),
      primaryKey({
        columns: [table.instituteId, table.userId, table.role],
        name: "user_roles_pkey",
      }),
      pgPolicy("iso", {
        as: "restrictive",
        for: "all",
        to: ["tazkiyah_app"],
        using: sql`(institute_id = ( SELECT app.current_institute_id() AS current_institute_id))`,
        withCheck: sql`(institute_id = ( SELECT app.current_institute_id() AS current_institute_id))`,
      }),
      pgPolicy("role_read", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`(user_id = (select app.current_user_id()) and app.has_role(role))
  or (select app.has_role('admin'))`,
      }),
      check(
        "user_roles_role_check",
        sql`role = ANY (ARRAY['donor'::text, 'student'::text, 'teacher'::text, 'editor'::text, 'finance_officer'::text, 'admin'::text])`,
      ),
      check(
        "user_roles_check",
        sql`(NOT can_widen_scope) OR (role = 'teacher'::text)`,
      ),
    ],
  )
  .enableRLS();
// PostgreSQL view definitions and security barriers are managed by custom migrations.
export const institutePublic = publicApi
  .view("institute_public", {
    instituteId: uuid("institute_id"),
    name: localizedText("name"),
    shortName: localizedText("short_name"),
    parentBody: localizedText("parent_body"),
    theme: jsonb(),
    address: localizedText("address"),
    contact: jsonb(),
    languages: text().array(),
    defaultLanguage: text("default_language"),
    timezone: text(),
    baseCurrency: char("base_currency", { length: 3 }),
    foundedYear: smallint("founded_year"),
    enabledModules: text("enabled_modules").array(),
    bankAccounts: jsonb("bank_accounts"),
  })
  .existing();

export const instituteLogo = publicApi
  .view("institute_logo", {
    instituteId: uuid("institute_id"),
    id: uuid(),
    storageKey: text("storage_key"),
    variants: jsonb(),
    altText: localizedText("alt_text"),
  })
  .existing();

export const publicSitePages = publicApi
  .view("site_pages", {
    instituteId: uuid("institute_id"),
    slug: text(),
    title: localizedText("title"),
    body: localizedText("body"),
    facts: jsonb(),
    publishedAt: timestamp("published_at", {
      withTimezone: true,
      mode: "string",
    }),
    coverStorageKey: text("cover_storage_key"),
    coverVariants: jsonb("cover_variants"),
    coverAltText: localizedText("cover_alt_text"),
  })
  .existing();

export const causes = app
  .table(
    "causes",
    {
      id: uuid().defaultRandom().primaryKey().notNull(),
      instituteId: uuid("institute_id")
        .notNull()
        .references(() => institutes.id),
      slug: text().notNull(),
      causeType: text("cause_type").notNull(),
      title: localizedText("title").notNull(),
      summary: localizedText("summary").notNull(),
      body: localizedText("body"),
      coverMediaId: uuid("cover_media_id"),
      targetPaisa: bigint("target_paisa", { mode: "bigint" }),
      targetPeriod: text("target_period"),
      stockYearStartMonth: smallint("stock_year_start_month"),
      startsOn: date("starts_on"),
      endsOn: date("ends_on"),
      acceptsZakat: boolean("accepts_zakat").default(false).notNull(),
      zakatApprovedBy: localizedText("zakat_approved_by"),
      status: text().default("draft").notNull(),
      revision: uuid().defaultRandom().notNull(),
      listedAsProject: boolean("listed_as_project").default(false).notNull(),
      category: text(),
      displayOrder: smallint("display_order").default(0).notNull(),
      createdAt: timestamp("created_at", { withTimezone: true })
        .defaultNow()
        .notNull(),
    },
    (table) => [
      index("causes_cover_media").on(table.instituteId, table.coverMediaId),
      unique().on(table.instituteId, table.id),
      unique().on(table.instituteId, table.slug),
      foreignKey({
        columns: [table.instituteId, table.coverMediaId],
        foreignColumns: [mediaAssets.instituteId, mediaAssets.id],
      }),
      index().on(table.instituteId, table.status, table.displayOrder),
      check(
        "causes_slug_check",
        sql`slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(slug) <= 80`,
      ),
      check(
        "causes_status_check",
        sql`status in ('draft', 'active', 'closed', 'archived')`,
      ),
      check(
        "causes_target_check",
        sql`target_paisa is null or target_paisa > 0`,
      ),
      check(
        "causes_dates_check",
        sql`starts_on is null or ends_on is null or ends_on >= starts_on`,
      ),
      check(
        "causes_zakat_approval_check",
        sql`accepts_zakat or zakat_approved_by is null`,
      ),
      check(
        "causes_type_rules_check",
        sql`
        coalesce(
          (cause_type = 'campaign' and target_paisa is not null and ends_on is not null
            and target_period is null and stock_year_start_month is null)
          or (cause_type = 'ongoing' and ends_on is null
            and target_period in ('monthly', 'yearly') and stock_year_start_month is null)
          or (cause_type = 'yearly_stock' and ends_on is null
            and target_period is null and stock_year_start_month between 1 and 12),
          false
        )
      `,
      ),
      pgPolicy("iso", {
        as: "restrictive",
        for: "all",
        to: ["tazkiyah_app"],
        using: sql`institute_id = (select app.current_institute_id())`,
        withCheck: sql`institute_id = (select app.current_institute_id())`,
      }),
    ],
  )
  .enableRLS();

export const publicCauses = publicApi
  .view("causes", {
    id: uuid(),
    slug: text(),
    causeType: text("cause_type"),
    title: localizedText("title"),
    summary: localizedText("summary"),
    body: localizedText("body"),
    targetPaisa: bigint("target_paisa", { mode: "bigint" }),
    targetPeriod: text("target_period"),
    stockYearStartMonth: smallint("stock_year_start_month"),
    startsOn: date("starts_on"),
    endsOn: date("ends_on"),
    acceptsZakat: boolean("accepts_zakat"),
    zakatApprovedBy: localizedText("zakat_approved_by"),
    status: text(),
    displayOrder: smallint("display_order"),
    createdAt: timestamp("created_at", { withTimezone: true }),
    raisedPaisa: numeric("raised_paisa"),
    lifetimeRaisedPaisa: numeric("lifetime_raised_paisa"),
  })
  .existing();

const manualDonationIsolation = () =>
  pgPolicy("iso", {
    as: "restrictive",
    for: "all",
    to: ["tazkiyah_app", "tazkiyah_auth"],
    using: sql`institute_id = (select app.current_institute_id())`,
    withCheck: sql`institute_id = (select app.current_institute_id())`,
  });

export const donors = app
  .table(
    "donors",
    {
      id: uuid().defaultRandom().primaryKey(),
      instituteId: uuid("institute_id")
        .notNull()
        .references(() => institutes.id),
      kind: text().default("person").notNull(),
      userId: uuid("user_id"),
      // Lower-case text instead of citext; the check keeps it case-blind.
      email: text(),
      emailVerifiedAt: timestamp("email_verified_at", { withTimezone: true }),
      legalName: text("legal_name"),
      phone: text(),
      displayName: text("display_name"),
      photoMediaId: uuid("photo_media_id"),
      profileLinks: jsonb("profile_links").default([]).notNull(),
      profilePublic: boolean("profile_public").default(false).notNull(),
      preferredLanguage: text("preferred_language").default("en").notNull(),
      reminderOptIn: boolean("reminder_opt_in").default(false).notNull(),
      reminderOptInAt: timestamp("reminder_opt_in_at", { withTimezone: true }),
      claimedAt: timestamp("claimed_at", { withTimezone: true }),
      erasedAt: timestamp("erased_at", { withTimezone: true }),
      createdAt: timestamp("created_at", { withTimezone: true })
        .defaultNow()
        .notNull(),
    },
    (table) => [
      index("donors_photo_media").on(table.instituteId, table.photoMediaId),
      unique().on(table.instituteId, table.id),
      unique().on(table.instituteId, table.email),
      unique().on(table.instituteId, table.userId),
      foreignKey({
        columns: [table.instituteId, table.userId],
        foreignColumns: [users.instituteId, users.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.photoMediaId],
        foreignColumns: [mediaAssets.instituteId, mediaAssets.id],
      }),
      check(
        "donors_email_check",
        sql`length(email) <= 254 and email = lower(btrim(email)) and email ~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'`,
      ),
      check("donors_language_check", sql`preferred_language in ('en', 'ur')`),
      check(
        "donors_kind_check",
        sql`kind in ('person', 'organisation', 'institute')`,
      ),
      check(
        "donors_text_check",
        sql`
        (legal_name is null or (length(legal_name) between 1 and 200 and legal_name = btrim(legal_name) and legal_name !~ '[[:cntrl:]]'))
        and (display_name is null or (length(display_name) between 1 and 80 and display_name = btrim(display_name) and display_name !~ '[[:cntrl:]]'))
        and (phone is null or phone ~ '^[+0-9][0-9 ()-]{4,31}$')
      `,
      ),
      check(
        "donors_profile_links_check",
        sql`app.valid_profile_links(profile_links)`,
      ),
      check(
        "donors_reminder_check",
        sql`not reminder_opt_in or reminder_opt_in_at is not null`,
      ),
      check(
        "donors_claim_check",
        sql`claimed_at is null or user_id is not null`,
      ),
      check(
        "donors_erasure_check",
        sql`
        erased_at is null or (email is null and legal_name is null and phone is null
          and display_name is null and photo_media_id is null and profile_links = '[]'::jsonb
          and not profile_public and not reminder_opt_in)
      `,
      ),
      manualDonationIsolation(),
      // The donor's own row (04 §6.4, P2-E5-T40): account and trail-link donors
      // read it; only account donors change it.
      pgPolicy("donors_own_read", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`id in (select app.my_donor_ids())`,
      }),
      pgPolicy("donors_own_update", {
        as: "permissive",
        for: "update",
        to: ["tazkiyah_app"],
        using: sql`user_id = (select app.current_user_id())`,
        withCheck: sql`user_id = (select app.current_user_id())`,
      }),
    ],
  )
  .enableRLS();

// A promise to give each month or year until card payments arrive (04 §8.8,
// 06 §13.1). Each payment is an ordinary donation linked by pledge_id.
export const recurringPledges = app
  .table(
    "recurring_pledges",
    {
      id: uuid().defaultRandom().primaryKey(),
      instituteId: uuid("institute_id")
        .notNull()
        .references(() => institutes.id),
      donorId: uuid("donor_id").notNull(),
      causeId: uuid("cause_id"),
      donationType: text("donation_type").notNull(),
      frequency: text().notNull(),
      amountPaisa: bigint("amount_paisa", { mode: "bigint" }).notNull(),
      isAnonymous: boolean("is_anonymous").default(true).notNull(),
      startsOn: date("starts_on").notNull(),
      status: text().default("active").notNull(),
      missedPeriods: smallint("missed_periods").default(0).notNull(),
      createdAt: timestamp("created_at", { withTimezone: true })
        .defaultNow()
        .notNull(),
      cancelledAt: timestamp("cancelled_at", { withTimezone: true }),
    },
    (table) => [
      unique().on(table.instituteId, table.id),
      index("recurring_pledges_donor").on(table.instituteId, table.donorId),
      index("recurring_pledges_cause")
        .on(table.instituteId, table.causeId)
        .where(sql`cause_id is not null`),
      foreignKey({
        columns: [table.instituteId, table.donorId],
        foreignColumns: [donors.instituteId, donors.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.causeId],
        foreignColumns: [causes.instituteId, causes.id],
      }),
      check(
        "recurring_pledges_type_check",
        sql`donation_type in ('zakat', 'sadaqah', 'general') and frequency in ('monthly', 'yearly')`,
      ),
      check(
        "recurring_pledges_amount_check",
        sql`amount_paisa between 100 and 99999999999900 and amount_paisa % 100 = 0`,
      ),
      check(
        "recurring_pledges_status_check",
        sql`status in ('active', 'lapsed', 'cancelled') and (status = 'cancelled') = (cancelled_at is not null) and missed_periods >= 0`,
      ),
      manualDonationIsolation(),
    ],
  )
  .enableRLS();

export const receiptCounters = app
  .table(
    "receipt_counters",
    {
      instituteId: uuid("institute_id")
        .notNull()
        .references(() => institutes.id),
      year: smallint().notNull(),
      lastNumber: bigint("last_number", { mode: "bigint" }).notNull(),
    },
    (table) => [
      primaryKey({ columns: [table.instituteId, table.year] }),
      check(
        "receipt_counters_range_check",
        sql`year between 1 and 9999 and last_number > 0`,
      ),
      manualDonationIsolation(),
    ],
  )
  .enableRLS();

export const donations = app
  .table(
    "donations",
    {
      id: uuid().defaultRandom().primaryKey(),
      instituteId: uuid("institute_id")
        .notNull()
        .references(() => institutes.id),
      operationId: uuid("operation_id").notNull(),
      publicRef: text("public_ref")
        .default(sql`app.new_public_ref()`)
        .notNull(),
      bankAccountId: uuid("bank_account_id"),
      bankReference: text("bank_reference"),
      creditedOn: date("credited_on").notNull(),
      amountMinor: bigint("amount_minor", { mode: "bigint" }).notNull(),
      amountPaisa: bigint("amount_paisa", { mode: "bigint" }).notNull(),
      currency: char({ length: 3 }).default("PKR").notNull(),
      fxRate: numeric("fx_rate", { precision: 18, scale: 8 }),
      method: text().default("bank_transfer").notNull(),
      frequency: text().default("one_off").notNull(),
      donationType: text("donation_type").notNull(),
      donorId: uuid("donor_id").notNull(),
      causeId: uuid("cause_id"),
      pledgeId: uuid("pledge_id"),
      gatewayPaymentId: text("gateway_payment_id"),
      // Single-column on purpose: a platform-fund allocation belongs to the
      // fund institute, not this one (04 §9.5).
      sourceAllocationId: uuid("source_allocation_id").references(
        (): AnyPgColumn => allocations.id,
      ),
      receiptNumber: text("receipt_number").notNull(),
      receiptLocale: text("receipt_locale").notNull(),
      isAnonymous: boolean("is_anonymous").default(true).notNull(),
      trailPublic: boolean("trail_public").default(false).notNull(),
      status: text().default("recorded").notNull(),
      privateNote: text("private_note"),
      recordedBy: uuid("recorded_by").notNull(),
      recordedAt: timestamp("recorded_at", { withTimezone: true })
        .defaultNow()
        .notNull(),
    },
    (table) => [
      index("donations_cause").on(table.instituteId, table.causeId),
      index("donations_recorded_by").on(table.instituteId, table.recordedBy),
      unique().on(table.instituteId, table.id),
      unique().on(table.instituteId, table.operationId),
      unique().on(table.instituteId, table.receiptNumber),
      unique().on(table.instituteId, table.publicRef),
      unique().on(table.instituteId, table.gatewayPaymentId),
      uniqueIndex("donations_recorded_bank_reference")
        .on(table.instituteId, table.bankAccountId, table.bankReference)
        .where(sql`status = 'recorded'`),
      index().on(
        table.instituteId,
        table.bankAccountId,
        table.creditedOn,
        table.amountPaisa,
      ),
      index().on(table.instituteId, table.recordedAt, table.id),
      index("donations_guest_trail_index")
        .on(
          table.instituteId,
          table.donorId,
          table.recordedAt.desc(),
          table.id.desc(),
        )
        .where(sql`donor_id is not null`),
      foreignKey({
        columns: [table.instituteId, table.bankAccountId],
        foreignColumns: [
          instituteBankAccounts.instituteId,
          instituteBankAccounts.id,
        ],
      }),
      foreignKey({
        columns: [table.instituteId, table.causeId],
        foreignColumns: [causes.instituteId, causes.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.donorId],
        foreignColumns: [donors.instituteId, donors.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.pledgeId],
        foreignColumns: [recurringPledges.instituteId, recurringPledges.id],
      }),
      index("donations_pledge")
        .on(table.instituteId, table.pledgeId)
        .where(sql`pledge_id is not null`),
      foreignKey({
        columns: [table.instituteId, table.recordedBy],
        foreignColumns: [users.instituteId, users.id],
      }),
      check(
        "donations_amount_check",
        sql`amount_paisa between 100 and 99999999999900 and amount_paisa % 100 = 0`,
      ),
      check(
        "donations_bank_reference_check",
        sql`bank_reference is null or (length(bank_reference) between 1 and 120 and bank_reference = btrim(bank_reference) and bank_reference !~ '[[:cntrl:]]')`,
      ),
      check(
        "donations_bank_guard_check",
        sql`method <> 'bank_transfer' or (bank_account_id is not null and bank_reference is not null)`,
      ),
      check(
        "donations_method_check",
        sql`method in ('bank_transfer', 'card', 'jazzcash', 'easypaisa', 'platform_transfer') and frequency in ('one_off', 'monthly', 'yearly')`,
      ),
      check(
        "donations_source_check",
        sql`(method = 'platform_transfer') = (source_allocation_id is not null) and (gateway_payment_id is null or method in ('card', 'jazzcash', 'easypaisa'))`,
      ),
      check(
        "donations_currency_check",
        sql`currency ~ '^[A-Z]{3}$' and amount_minor > 0 and ((currency = 'PKR' and amount_minor = amount_paisa and fx_rate is null) or (currency <> 'PKR' and fx_rate > 0))`,
      ),
      check(
        "donations_manual_source_check",
        sql`currency = 'PKR' and method = 'bank_transfer' and frequency = 'one_off'`,
      ),
      check("donations_public_ref_check", sql`public_ref ~ '^[a-z2-7]{10}$'`),
      check(
        "donations_private_note_check",
        sql`private_note is null or length(private_note) between 1 and 2000`,
      ),
      check(
        "donations_type_check",
        sql`donation_type in ('zakat', 'sadaqah', 'general')`,
      ),
      check("donations_locale_check", sql`receipt_locale in ('en', 'ur')`),
      check("donations_status_check", sql`status in ('recorded', 'reversed')`),
      check("donations_anonymity_check", sql`is_anonymous`),
      manualDonationIsolation(),
      // 04 §6.4: the donor (account or trail token) reads their own
      // donations, through granted columns only (app.donor_trail).
      pgPolicy("donations_own_read", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`donor_id in (select app.my_donor_ids())`,
      }),
    ],
  )
  .enableRLS();

// Daily or weekly spending reports (04 §9.7, D-013).
export const spendingReports = app
  .table(
    "spending_reports",
    {
      id: uuid().defaultRandom().primaryKey(),
      instituteId: uuid("institute_id")
        .notNull()
        .references(() => institutes.id),
      periodKind: text("period_kind").notNull(),
      periodStart: date("period_start").notNull(),
      periodEnd: date("period_end").notNull(),
      title: localizedText().notNull(),
      notes: localizedText(),
      status: text().default("draft").notNull(),
      publishedAt: timestamp("published_at", { withTimezone: true }),
      publishedBy: uuid("published_by"),
      createdBy: uuid("created_by").notNull(),
      createdAt: timestamp("created_at", { withTimezone: true })
        .defaultNow()
        .notNull(),
    },
    (table) => [
      unique().on(table.instituteId, table.id),
      index("spending_reports_period").on(
        table.instituteId,
        table.periodStart.desc(),
      ),
      index("spending_reports_published_by")
        .on(table.instituteId, table.publishedBy)
        .where(sql`published_by is not null`),
      index("spending_reports_created_by").on(
        table.instituteId,
        table.createdBy,
      ),
      foreignKey({
        columns: [table.instituteId, table.publishedBy],
        foreignColumns: [users.instituteId, users.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.createdBy],
        foreignColumns: [users.instituteId, users.id],
      }),
      check(
        "spending_reports_period_check",
        sql`period_kind in ('daily', 'weekly', 'custom') and period_end >= period_start and (period_kind <> 'daily' or period_end = period_start)`,
      ),
      check(
        "spending_reports_status_check",
        sql`status in ('draft', 'published') and (status = 'published') = (published_at is not null) and (published_at is null) = (published_by is null)`,
      ),
      pgPolicy("iso", {
        as: "restrictive",
        for: "all",
        to: ["tazkiyah_app", "tazkiyah_auth"],
        using: sql`institute_id = (select app.current_institute_id())`,
        withCheck: sql`institute_id = (select app.current_institute_id())`,
      }),
      pgPolicy("spending_reports_staff_read", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`(select app.has_role('admin')) or (select app.has_role('finance_officer'))`,
      }),
    ],
  )
  .enableRLS();

// One recorded use of a cause's money (04 §9.7, REQ-TRL-011).
export const spendingEntries = app
  .table(
    "spending_entries",
    {
      id: uuid().defaultRandom().primaryKey(),
      instituteId: uuid("institute_id")
        .notNull()
        .references(() => institutes.id),
      causeId: uuid("cause_id").notNull(),
      amountPaisa: bigint("amount_paisa", { mode: "bigint" }).notNull(),
      spentOn: date("spent_on").notNull(),
      description: localizedText().notNull(),
      receiptMediaId: uuid("receipt_media_id"),
      receiptPublic: boolean("receipt_public").default(true).notNull(),
      reportId: uuid("report_id"),
      status: text().default("draft").notNull(),
      recordedBy: uuid("recorded_by").notNull(),
      createdAt: timestamp("created_at", { withTimezone: true })
        .defaultNow()
        .notNull(),
    },
    (table) => [
      unique().on(table.instituteId, table.id),
      index("spending_entries_cause").on(
        table.instituteId,
        table.causeId,
        table.spentOn,
      ),
      index("spending_entries_report")
        .on(table.instituteId, table.reportId)
        .where(sql`report_id is not null`),
      index("spending_entries_receipt")
        .on(table.instituteId, table.receiptMediaId)
        .where(sql`receipt_media_id is not null`),
      index("spending_entries_recorded_by").on(
        table.instituteId,
        table.recordedBy,
      ),
      foreignKey({
        columns: [table.instituteId, table.causeId],
        foreignColumns: [causes.instituteId, causes.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.receiptMediaId],
        foreignColumns: [mediaAssets.instituteId, mediaAssets.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.reportId],
        foreignColumns: [spendingReports.instituteId, spendingReports.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.recordedBy],
        foreignColumns: [users.instituteId, users.id],
      }),
      check(
        "spending_entries_amount_check",
        sql`amount_paisa between 100 and 99999999999900 and amount_paisa % 100 = 0`,
      ),
      check(
        "spending_entries_status_check",
        sql`status in ('draft', 'recorded', 'reversed') and (status <> 'draft' or report_id is null)`,
      ),
      pgPolicy("iso", {
        as: "restrictive",
        for: "all",
        to: ["tazkiyah_app", "tazkiyah_auth"],
        using: sql`institute_id = (select app.current_institute_id())`,
        withCheck: sql`institute_id = (select app.current_institute_id())`,
      }),
      pgPolicy("spending_entries_staff_read", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`(select app.has_role('admin')) or (select app.has_role('finance_officer'))`,
      }),
    ],
  )
  .enableRLS();

export const allocations = app
  .table(
    "allocations",
    {
      id: uuid().defaultRandom().primaryKey(),
      instituteId: uuid("institute_id")
        .notNull()
        .references(() => institutes.id),
      donationId: uuid("donation_id").notNull(),
      causeId: uuid("cause_id"),
      kind: text().default("to_cause").notNull(),
      donationType: text("donation_type").notNull(),
      fromAllocationId: uuid("from_allocation_id"),
      spendingEntryId: uuid("spending_entry_id"),
      // Single-column on purpose: the receiving institute is another tenant
      // (04 §9.5).
      targetInstituteId: uuid("target_institute_id").references(
        () => institutes.id,
      ),
      amountPaisa: bigint("amount_paisa", { mode: "bigint" }).notNull(),
      isReversal: boolean("is_reversal").default(false).notNull(),
      reversesAllocationId: uuid("reverses_allocation_id"),
      reason: text(),
      createdBy: uuid("created_by").notNull(),
      createdAt: timestamp("created_at", { withTimezone: true })
        .defaultNow()
        .notNull(),
    },
    (table) => [
      index("allocations_donation").on(table.instituteId, table.donationId),
      index("allocations_created_by").on(table.instituteId, table.createdBy),
      unique().on(table.instituteId, table.id),
      index().on(table.instituteId, table.causeId, table.donationId),
      index("allocations_from_allocation")
        .on(table.instituteId, table.fromAllocationId)
        .where(sql`from_allocation_id is not null`),
      index("allocations_spending_entry")
        .on(table.instituteId, table.spendingEntryId)
        .where(sql`spending_entry_id is not null`),
      unique().on(table.instituteId, table.reversesAllocationId),
      foreignKey({
        columns: [table.instituteId, table.donationId],
        foreignColumns: [donations.instituteId, donations.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.fromAllocationId],
        foreignColumns: [table.instituteId, table.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.reversesAllocationId],
        foreignColumns: [table.instituteId, table.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.spendingEntryId],
        foreignColumns: [spendingEntries.instituteId, spendingEntries.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.causeId],
        foreignColumns: [causes.instituteId, causes.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.createdBy],
        foreignColumns: [users.instituteId, users.id],
      }),
      check(
        "allocations_shape_check",
        sql`(kind = 'to_cause' and cause_id is not null and from_allocation_id is null and spending_entry_id is null and target_institute_id is null) or (kind = 'to_spending' and cause_id is not null and from_allocation_id is not null and spending_entry_id is not null and target_institute_id is null) or (kind = 'to_institute' and target_institute_id is not null and cause_id is null and from_allocation_id is null and spending_entry_id is null)`,
      ),
      check(
        "allocations_reversal_check",
        sql`is_reversal = (reverses_allocation_id is not null) and (reason is null) = (not is_reversal) and (reason is null or (length(reason) between 1 and 500 and reason = btrim(reason)))`,
      ),
      check(
        "allocations_type_check",
        sql`donation_type in ('zakat', 'sadaqah', 'general')`,
      ),
      check("allocations_amount_check", sql`amount_paisa > 0`),
      manualDonationIsolation(),
    ],
  )
  .enableRLS();

export const trailEvents = app
  .table(
    "trail_events",
    {
      id: bigint({ mode: "bigint" }).generatedAlwaysAsIdentity().primaryKey(),
      instituteId: uuid("institute_id")
        .notNull()
        .references(() => institutes.id),
      donationId: uuid("donation_id").notNull(),
      eventType: text("event_type").notNull(),
      occurredOn: date("occurred_on").notNull(),
      amountPaisa: bigint("amount_paisa", { mode: "bigint" }).notNull(),
      causeId: uuid("cause_id"),
      allocationId: uuid("allocation_id"),
      spendingEntryId: uuid("spending_entry_id"),
      spendingReportId: uuid("spending_report_id"),
      reversesEventId: bigint("reverses_event_id", { mode: "bigint" }),
      reason: text(),
      details: jsonb().default({}).notNull(),
      recordedBy: uuid("recorded_by").notNull(),
      recordedAt: timestamp("recorded_at", { withTimezone: true })
        .defaultNow()
        .notNull(),
    },
    (table) => [
      index("trail_events_cause").on(table.instituteId, table.causeId),
      index("trail_events_recorded_by").on(table.instituteId, table.recordedBy),
      unique().on(table.instituteId, table.id),
      uniqueIndex("trail_events_one_received")
        .on(table.instituteId, table.donationId)
        .where(sql`event_type = 'received'`),
      unique().on(table.instituteId, table.allocationId),
      unique().on(table.instituteId, table.reversesEventId),
      foreignKey({
        columns: [table.instituteId, table.reversesEventId],
        foreignColumns: [table.instituteId, table.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.spendingEntryId],
        foreignColumns: [spendingEntries.instituteId, spendingEntries.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.spendingReportId],
        foreignColumns: [spendingReports.instituteId, spendingReports.id],
      }),
      index("trail_events_spending_entry")
        .on(table.instituteId, table.spendingEntryId)
        .where(sql`spending_entry_id is not null`),
      index("trail_events_spending_report")
        .on(table.instituteId, table.spendingReportId)
        .where(sql`spending_report_id is not null`),
      index("trail_events_donation_index").on(
        table.instituteId,
        table.donationId,
        table.id,
      ),
      foreignKey({
        columns: [table.instituteId, table.donationId],
        foreignColumns: [donations.instituteId, donations.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.causeId],
        foreignColumns: [causes.instituteId, causes.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.allocationId],
        foreignColumns: [allocations.instituteId, allocations.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.recordedBy],
        foreignColumns: [users.instituteId, users.id],
      }),
      check("trail_events_amount_check", sql`amount_paisa > 0`),
      check(
        "trail_events_shape_check",
        sql`(event_type = 'received' and cause_id is null and allocation_id is null and spending_entry_id is null and spending_report_id is null and reverses_event_id is null) or (event_type = 'allocated' and allocation_id is not null and spending_entry_id is null and spending_report_id is null and reverses_event_id is null) or (event_type = 'spent' and cause_id is not null and allocation_id is not null and spending_entry_id is not null and spending_report_id is null and reverses_event_id is null) or (event_type = 'reported' and cause_id is null and allocation_id is null and spending_entry_id is null and spending_report_id is not null and reverses_event_id is null) or (event_type = 'reversal' and reverses_event_id is not null and spending_report_id is null)`,
      ),
      check(
        "trail_events_reason_check",
        sql`(reason is null) = (event_type <> 'reversal') and (reason is null or (length(reason) between 1 and 500 and reason = btrim(reason)))`,
      ),
      check(
        "trail_events_details_check",
        sql`jsonb_typeof(details) = 'object'`,
      ),
      manualDonationIsolation(),
      pgPolicy("trail_events_own_read", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`exists (select 1 from app.donations d where d.institute_id = trail_events.institute_id and d.id = trail_events.donation_id and d.donor_id in (select app.my_donor_ids()))`,
      }),
    ],
  )
  .enableRLS();

export const trailLinks = app
  .table(
    "trail_links",
    {
      id: uuid().defaultRandom().primaryKey(),
      instituteId: uuid("institute_id")
        .notNull()
        .references(() => institutes.id),
      donorId: uuid("donor_id").notNull(),
      tokenHash: text("token_hash").notNull(),
      // Null only for links issued before P1-E3-T44.
      tokenHint: text("token_hint"),
      createdAt: timestamp("created_at", { withTimezone: true })
        .defaultNow()
        .notNull(),
      createdBy: uuid("created_by").notNull(),
      expiresAt: timestamp("expires_at", { withTimezone: true }),
      revokedAt: timestamp("revoked_at", { withTimezone: true }),
      revokedBy: uuid("revoked_by"),
      revokeReason: text("revoke_reason"),
      lastUsedAt: timestamp("last_used_at", { withTimezone: true }),
    },
    (table) => [
      index("trail_links_donor").on(table.instituteId, table.donorId),
      index("trail_links_created_by").on(table.instituteId, table.createdBy),
      index("trail_links_revoked_by").on(table.instituteId, table.revokedBy),
      unique().on(table.instituteId, table.id),
      unique("trail_links_token_hash_unique").on(table.tokenHash),
      uniqueIndex("trail_links_one_active")
        .on(table.instituteId, table.donorId)
        .where(sql`revoked_at is null`),
      foreignKey({
        columns: [table.instituteId, table.donorId],
        foreignColumns: [donors.instituteId, donors.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.createdBy],
        foreignColumns: [users.instituteId, users.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.revokedBy],
        foreignColumns: [users.instituteId, users.id],
      }),
      check("trail_links_hash_check", sql`token_hash ~ '^[0-9a-f]{64}$'`),
      check(
        "trail_links_revocation_check",
        sql`(revoked_at is null) = (revoked_by is null) and (revoke_reason is null or (revoked_at is not null and length(revoke_reason) between 1 and 200 and revoke_reason !~ '[[:cntrl:]]'))`,
      ),
      check(
        "trail_links_hint_check",
        sql`token_hint is null or token_hint ~ '^[A-Za-z0-9_-]{4}$'`,
      ),
      check(
        "trail_links_expiry_check",
        sql`expires_at is null or expires_at > created_at`,
      ),
      manualDonationIsolation(),
      // 04 §6.4: the donor reads their own links' metadata (never the hash,
      // which is not granted); admins and finance officers read all.
      pgPolicy("trail_links_own_read", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`donor_id in (select app.my_donor_ids()) or (select app.has_role('admin')) or (select app.has_role('finance_officer'))`,
      }),
    ],
  )
  .enableRLS();

export const mail = pgSchema("mail");

export const receiptEmailJobs = app
  .table(
    "receipt_email_jobs",
    {
      id: uuid().defaultRandom().primaryKey(),
      instituteId: uuid("institute_id")
        .notNull()
        .references(() => institutes.id),
      donationId: uuid("donation_id").notNull(),
      donorId: uuid("donor_id").notNull(),
      toEmail: text("to_email"),
      state: text().default("pending").notNull(),
      attempts: smallint().default(0).notNull(),
      firstAttemptAt: timestamp("first_attempt_at", { withTimezone: true }),
      nextAttemptAt: timestamp("next_attempt_at", { withTimezone: true })
        .defaultNow()
        .notNull(),
      claimToken: uuid("claim_token"),
      leaseExpiresAt: timestamp("lease_expires_at", { withTimezone: true }),
      snapshot: jsonb(),
      trailLinkId: uuid("trail_link_id"),
      payloadHash: text("payload_hash"),
      lastError: text("last_error"),
      createdAt: timestamp("created_at", { withTimezone: true })
        .defaultNow()
        .notNull(),
      finishedAt: timestamp("finished_at", { withTimezone: true }),
    },
    (table) => [
      index("receipt_email_jobs_donor").on(table.instituteId, table.donorId),
      index("receipt_email_jobs_trail_link").on(
        table.instituteId,
        table.trailLinkId,
      ),
      unique().on(table.instituteId, table.id),
      unique().on(table.instituteId, table.donationId),
      index("receipt_email_jobs_pending")
        .on(table.nextAttemptAt, table.id)
        .where(sql`state = 'pending'`),
      index("receipt_email_jobs_leased")
        .on(table.leaseExpiresAt, table.id)
        .where(sql`state = 'leased'`),
      foreignKey({
        columns: [table.instituteId, table.donationId],
        foreignColumns: [donations.instituteId, donations.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.donorId],
        foreignColumns: [donors.instituteId, donors.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.trailLinkId],
        foreignColumns: [trailLinks.instituteId, trailLinks.id],
      }),
      check(
        "receipt_email_jobs_state_check",
        sql`state in ('pending', 'leased', 'sent', 'failed')`,
      ),
      check(
        "receipt_email_jobs_attempts_check",
        sql`attempts between 0 and 6 and (attempts = 0) = (first_attempt_at is null)`,
      ),
      check(
        "receipt_email_jobs_lease_check",
        sql`(state = 'leased') = (claim_token is not null) and (claim_token is null) = (lease_expires_at is null)`,
      ),
      check(
        "receipt_email_jobs_terminal_check",
        sql`
        (state in ('sent', 'failed')) = (finished_at is not null)
        and (finished_at is null) = (to_email is not null)
        and (finished_at is null or snapshot is null)
      `,
      ),
      check(
        "receipt_email_jobs_payload_check",
        sql`payload_hash is null or payload_hash ~ '^[0-9a-f]{64}$'`,
      ),
      check(
        "receipt_email_jobs_error_check",
        sql`
        last_error is null or last_error in ('rate_limited', 'provider_unavailable', 'network_error',
          'configuration', 'provider_rejected', 'recipient_changed', 'donation_unavailable',
          'payload_changed', 'attempts_exhausted', 'retry_window_expired')
      `,
      ),
      manualDonationIsolation(),
    ],
  )
  .enableRLS();

// Classes (04 §7.3, REQ-TCH-005). Members and admins read a class; teachers
// and admins create one, and the creator joins it as its teacher.
export const classes = app
  .table(
    "classes",
    {
      id: uuid().defaultRandom().primaryKey(),
      instituteId: uuid("institute_id")
        .notNull()
        .references(() => institutes.id),
      name: localizedText().notNull(),
      yearLabel: text("year_label"),
      createdBy: uuid("created_by").notNull(),
      createdAt: timestamp("created_at", { withTimezone: true })
        .defaultNow()
        .notNull(),
      archivedAt: timestamp("archived_at", { withTimezone: true }),
    },
    (table) => [
      unique().on(table.instituteId, table.id),
      index("classes_created_by").on(table.instituteId, table.createdBy),
      foreignKey({
        columns: [table.instituteId, table.createdBy],
        foreignColumns: [users.instituteId, users.id],
      }),
      check(
        "classes_year_label_check",
        sql`year_label is null or (length(year_label) between 1 and 40 and year_label = btrim(year_label))`,
      ),
      pgPolicy("iso", {
        as: "restrictive",
        for: "all",
        to: ["tazkiyah_app"],
        using: sql`institute_id = (select app.current_institute_id())`,
        withCheck: sql`institute_id = (select app.current_institute_id())`,
      }),
      pgPolicy("classes_member_read", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`(select app.has_role('admin')) or created_by = (select app.current_user_id()) or app.is_class_member(id)`,
      }),
      pgPolicy("classes_staff_create", {
        as: "permissive",
        for: "insert",
        to: ["tazkiyah_app"],
        withCheck: sql`created_by = (select app.current_user_id()) and ((select app.has_role('teacher')) or (select app.has_role('admin')))`,
      }),
      pgPolicy("classes_teacher_update", {
        as: "permissive",
        for: "update",
        to: ["tazkiyah_app"],
        using: sql`(select app.has_role('admin')) or app.is_class_teacher(id)`,
        withCheck: sql`(select app.has_role('admin')) or app.is_class_teacher(id)`,
      }),
    ],
  )
  .enableRLS();

// Who is in a class, as student or teacher (04 §7.3). An ended membership
// stays, so past teachers can still trace a student (§6.2).
export const classMembers = app
  .table(
    "class_members",
    {
      id: uuid().defaultRandom().primaryKey(),
      instituteId: uuid("institute_id")
        .notNull()
        .references(() => institutes.id),
      classId: uuid("class_id").notNull(),
      userId: uuid("user_id").notNull(),
      memberRole: text("member_role").notNull(),
      joinedAt: date("joined_at")
        .default(sql`current_date`)
        .notNull(),
      endedAt: date("ended_at"),
      addedBy: uuid("added_by"),
    },
    (table) => [
      unique().on(table.instituteId, table.id),
      uniqueIndex("class_members_one_open")
        .on(table.instituteId, table.classId, table.userId, table.memberRole)
        .where(sql`ended_at is null`),
      index("class_members_user").on(table.instituteId, table.userId),
      index("class_members_class_role").on(
        table.instituteId,
        table.classId,
        table.memberRole,
      ),
      index("class_members_added_by").on(table.instituteId, table.addedBy),
      foreignKey({
        columns: [table.instituteId, table.classId],
        foreignColumns: [classes.instituteId, classes.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.userId],
        foreignColumns: [users.instituteId, users.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.addedBy],
        foreignColumns: [users.instituteId, users.id],
      }),
      check(
        "class_members_role_check",
        sql`member_role in ('student', 'teacher')`,
      ),
      check(
        "class_members_dates_check",
        sql`ended_at is null or ended_at >= joined_at`,
      ),
      pgPolicy("iso", {
        as: "restrictive",
        for: "all",
        to: ["tazkiyah_app"],
        using: sql`institute_id = (select app.current_institute_id())`,
        withCheck: sql`institute_id = (select app.current_institute_id())`,
      }),
      pgPolicy("class_members_read", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`user_id = (select app.current_user_id()) or (select app.has_role('admin')) or app.is_class_teacher(class_id)`,
      }),
      pgPolicy("class_members_add", {
        as: "permissive",
        for: "insert",
        to: ["tazkiyah_app"],
        withCheck: sql`added_by = (select app.current_user_id()) and ((select app.has_role('admin')) or (member_role = 'student' and app.is_class_teacher(class_id)))`,
      }),
      pgPolicy("class_members_end", {
        as: "permissive",
        for: "update",
        to: ["tazkiyah_app"],
        using: sql`(select app.has_role('admin')) or (member_role = 'student' and app.is_class_teacher(class_id))`,
        withCheck: sql`(select app.has_role('admin')) or (member_role = 'student' and app.is_class_teacher(class_id))`,
      }),
    ],
  )
  .enableRLS();

// A student's anonymous public identity (04 §7.4, REQ-STU-003). It holds only
// what others may see; the link to the student is in persona_links. Rows come
// only from app.create_student_account().
export const personas = app
  .table(
    "personas",
    {
      id: uuid().defaultRandom().primaryKey(),
      instituteId: uuid("institute_id")
        .notNull()
        .references(() => institutes.id),
      displayName: text("display_name").notNull(),
      avatarMediaId: uuid("avatar_media_id"),
      bio: text(),
      bioLanguage: text("bio_language"),
      showRealName: boolean("show_real_name").default(false).notNull(),
      isActive: boolean("is_active").default(true).notNull(),
      createdAt: timestamp("created_at", { withTimezone: true })
        .defaultNow()
        .notNull(),
      updatedAt: timestamp("updated_at", { withTimezone: true })
        .defaultNow()
        .notNull(),
    },
    (table) => [
      unique().on(table.instituteId, table.id),
      uniqueIndex("personas_display_name").on(
        table.instituteId,
        sql`lower(display_name)`,
      ),
      index("personas_avatar_media").on(table.instituteId, table.avatarMediaId),
      foreignKey({
        columns: [table.instituteId, table.avatarMediaId],
        foreignColumns: [mediaAssets.instituteId, mediaAssets.id],
      }),
      check(
        "personas_display_name_check",
        sql`app.persona_name_ok(display_name)`,
      ),
      check(
        "personas_bio_check",
        sql`bio is null or (length(bio) between 1 and 160 and bio ~ '[^[:space:]]' and not app.has_contact_details(bio))`,
      ),
      check(
        "personas_bio_language_check",
        sql`bio_language is null or bio_language in ('en', 'ur')`,
      ),
      pgPolicy("iso", {
        as: "restrictive",
        for: "all",
        to: ["tazkiyah_app"],
        using: sql`institute_id = (select app.current_institute_id())`,
        withCheck: sql`institute_id = (select app.current_institute_id())`,
      }),
      pgPolicy("personas_member_read", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`(select app.is_member())`,
      }),
      pgPolicy("personas_edit", {
        as: "permissive",
        for: "update",
        to: ["tazkiyah_app"],
        using: sql`app.can_trace_persona(id)`,
        withCheck: sql`app.can_trace_persona(id)`,
      }),
    ],
  )
  .enableRLS();

// The private link between a persona and its student (04 §7.4, REQ-SEC-007).
// Only the student, the student's teachers and admins read it. Nobody changes
// or deletes it.
export const personaLinks = app
  .table(
    "persona_links",
    {
      id: uuid().defaultRandom().primaryKey(),
      instituteId: uuid("institute_id")
        .notNull()
        .references(() => institutes.id),
      personaId: uuid("persona_id").notNull(),
      userId: uuid("user_id").notNull(),
      createdBy: uuid("created_by").notNull(),
      createdAt: timestamp("created_at", { withTimezone: true })
        .defaultNow()
        .notNull(),
    },
    (table) => [
      unique().on(table.instituteId, table.id),
      unique("persona_links_persona").on(table.instituteId, table.personaId),
      unique("persona_links_user").on(table.instituteId, table.userId),
      index("persona_links_created_by").on(table.instituteId, table.createdBy),
      foreignKey({
        columns: [table.instituteId, table.personaId],
        foreignColumns: [personas.instituteId, personas.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.userId],
        foreignColumns: [users.instituteId, users.id],
      }),
      foreignKey({
        columns: [table.instituteId, table.createdBy],
        foreignColumns: [users.instituteId, users.id],
      }),
      pgPolicy("iso", {
        as: "restrictive",
        for: "all",
        to: ["tazkiyah_app"],
        using: sql`institute_id = (select app.current_institute_id())`,
        withCheck: sql`institute_id = (select app.current_institute_id())`,
      }),
      pgPolicy("read_link", {
        as: "permissive",
        for: "select",
        to: ["tazkiyah_app"],
        using: sql`user_id = (select app.current_user_id()) or (select app.has_role('admin')) or app.is_teacher_of(user_id)`,
      }),
    ],
  )
  .enableRLS();
