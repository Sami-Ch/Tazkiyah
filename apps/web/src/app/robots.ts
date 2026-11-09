import type { MetadataRoute } from "next";
import { headers } from "next/headers";
import { publicSiteOrigin } from "@/server/public-site";

export const dynamic = "force-dynamic";

export default async function robots(): Promise<MetadataRoute.Robots> {
  const origin = publicSiteOrigin(new Headers(await headers()));
  if (!origin) return { rules: { userAgent: "*", disallow: "/" } };

  return {
    rules: { userAgent: "*", allow: "/", disallow: "/api/" },
    sitemap: new URL("/sitemap.xml", origin).href,
  };
}
