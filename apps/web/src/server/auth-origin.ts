export const authOriginHeader = "x-tazkiyah-auth-origin";

export function forwardedHttpsOrigin(headers: Headers) {
  const host = headers.get("host");
  if (headers.get("x-forwarded-proto") !== "https" || !host) return undefined;
  // Only accept a host, never credentials, a path, or a forwarded host list.
  if (!/^[a-z0-9.-]+(?::[0-9]+)?$/i.test(host)) return undefined;
  const origin = `https://${host}`;
  return URL.canParse(origin) ? new URL(origin).origin : undefined;
}
