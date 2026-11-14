const patterns = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] as const;

export function AvatarMark({
  preset,
  label,
}: {
  preset: number;
  label: string;
}) {
  const safe = Math.min(24, Math.max(1, preset));
  const pattern = ((safe - 1) % 12) + 1;
  const alt = safe > 12;
  return (
    <svg
      className={alt ? "hub-avatar hub-avatar-alt" : "hub-avatar"}
      viewBox="0 0 48 48"
      role="img"
      aria-label={label}
    >
      <rect width="48" height="48" rx="12" className="hub-avatar-plate" />
      {pattern === 1 && <path d="M24 8 28 20h12l-10 7 4 12-10-7-10 7 4-12L8 20h12z" />}
      {pattern === 2 && (
        <>
          <circle cx="24" cy="24" r="12" fill="none" stroke="currentColor" strokeWidth="2" />
          <circle cx="24" cy="24" r="6" fill="none" stroke="currentColor" strokeWidth="2" />
        </>
      )}
      {pattern === 3 && <path d="M24 8 40 24 24 40 8 24z" />}
      {pattern === 4 && (
        <>
          <path d="M10 12h28M10 24h28M10 36h28" fill="none" stroke="currentColor" strokeWidth="3" />
        </>
      )}
      {pattern === 5 && (
        <>
          <circle cx="16" cy="16" r="3" />
          <circle cx="32" cy="16" r="3" />
          <circle cx="16" cy="32" r="3" />
          <circle cx="32" cy="32" r="3" />
          <circle cx="24" cy="24" r="3" />
        </>
      )}
      {pattern === 6 && <path d="M30 10a12 12 0 1 0 0 28 10 10 0 1 1 0-28z" />}
      {pattern === 7 && (
        <path
          d="M14 12h20v24H14z"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
        />
      )}
      {pattern === 8 && <path d="M24 38C16 30 10 25 10 18a8 8 0 0 1 14-5 8 8 0 0 1 14 5c0 7-6 12-14 20z" />}
      {pattern === 9 && (
        <path
          d="M8 30c4-8 8-8 12 0s8 8 12 0 8-8 8 0"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
        />
      )}
      {pattern === 10 && (
        <path
          d="M16 8v32M32 8v32M8 16h32M8 32h32"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
        />
      )}
      {pattern === 11 && <path d="M24 8 36 16v16L24 40 12 32V16z" fill="none" stroke="currentColor" strokeWidth="2" />}
      {pattern === 12 && <path d="M10 32V18c0-8 28-8 28 0v14" fill="none" stroke="currentColor" strokeWidth="2" />}
      <title>{label}</title>
    </svg>
  );
}

export const avatarPresets = patterns.flatMap((pattern) => [pattern, pattern + 12]);
