export async function readJsonObject(request: Request, maxBytes = 16_384) {
  if (
    request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !==
      "application/json" ||
    !request.body
  )
    return null;

  const reader = request.body.getReader();
  const buffer = new Uint8Array(maxBytes);
  let length = 0;
  try {
    for (;;) {
      const chunk = await reader.read();
      if (chunk.done) break;
      if (length + chunk.value.length > buffer.length) {
        await reader.cancel();
        return null;
      }
      buffer.set(chunk.value, length);
      length += chunk.value.length;
    }
    const input: unknown = JSON.parse(
      new TextDecoder("utf-8", { fatal: true }).decode(
        buffer.subarray(0, length),
      ),
    );
    return input && typeof input === "object" && !Array.isArray(input)
      ? (input as Record<string, unknown>)
      : null;
  } catch {
    return null;
  } finally {
    reader.releaseLock();
  }
}

const uuidPattern = /^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i;

export function readUuid(value: unknown) {
  return typeof value === "string" && uuidPattern.test(value) ? value : null;
}
