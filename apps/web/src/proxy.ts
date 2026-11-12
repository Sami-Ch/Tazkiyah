import { routing } from "@tazkiyah/i18n/routing";
import createMiddleware from "next-intl/middleware";
import type { NextRequest } from "next/server";

// Public page metadata advertises only indexable translations.
const routeLocale = createMiddleware({ ...routing, alternateLinks: false });

export default function proxy(request: NextRequest) {
  const response = routeLocale(request);

  if (response.headers.has("location")) {
    response.headers.set("Cache-Control", "private, no-store");
  }

  return response;
}

export const config = {
  matcher: ["/((?!api|_next|_vercel|.*\\..*).*)"],
};
