import { defineConfig } from "drizzle-kit";

export default defineConfig({
  dialect: "postgresql",
  schema: [
    "./packages/core/src/db/schema.ts",
    "./packages/core/src/db/identity.ts",
  ],
  out: "./db/drizzle",
  schemaFilter: ["app", "public_api", "identity", "mail"],
});
