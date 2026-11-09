export function authRequest(path: string, body?: Record<string, unknown>) {
  return fetch(`/api/auth/${path}`, {
    cache: "no-store",
    ...(body && {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    }),
  });
}
