import openNext from "./.open-next/worker.js";
import { authOriginHeader } from "./src/server/auth-origin.ts";

const worker = {
  fetch(request, env, context) {
    const url = new URL(request.url);
    if (
      !url.pathname.startsWith("/api/auth/") &&
      url.pathname !== "/robots.txt" &&
      url.pathname !== "/sitemap.xml" &&
      !/^\/(en|ur)\/admin(?:\/|$)/.test(url.pathname) &&
      !/^\/(en|ur)\/account\/?$/.test(url.pathname) &&
      !/^\/(en|ur)\/causes(?:\/[a-z0-9-]+)?\/?$/.test(url.pathname) &&
      !/^\/(en|ur)\/donate(?:\/[a-z0-9-]+)?\/?$/.test(url.pathname) &&
      !/^\/(en|ur)(?:\/(?:about|facilities|daily-life|contact))?\/?$/.test(
        url.pathname,
      )
    ) {
      return openNext.fetch(request, env, context);
    }

    // OpenNext reconstructs the request URL before it reaches Next.js.
    const headers = new Headers(request.headers);
    headers.set(authOriginHeader, url.origin);
    headers.set("x-forwarded-host", url.host);
    headers.set("x-forwarded-proto", url.protocol.slice(0, -1));
    return openNext.fetch(new Request(request, { headers }), env, context);
  },
};

export default worker;
