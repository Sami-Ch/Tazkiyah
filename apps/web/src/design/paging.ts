/** Public lists load 20 rows at a time (02 §7, PD-02-08). */
export const pageSize = 20;
export const maxShown = 200;

export function listWindow(raw: string | null | undefined) {
  const parsed = Number(raw);
  const shown =
    Number.isInteger(parsed) &&
    parsed >= pageSize &&
    parsed <= maxShown &&
    parsed % pageSize === 0
      ? parsed
      : pageSize;
  return { take: shown, next: shown + pageSize };
}

export function nextPageHref(
  pathname: string,
  search: Record<string, string | undefined>,
  next: number,
) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(search)) {
    if (value) params.set(key, value);
  }
  params.set("shown", String(next));
  return `${pathname}?${params.toString()}`;
}
