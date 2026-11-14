const marks = {
  education: (
    <>
      <path d="M12 28 32 18 52 28 32 38Z" />
      <path d="M18 32v10c4 4 24 4 28 0V32" />
      <path d="M52 28v16" />
    </>
  ),
  meals: (
    <>
      <path d="M16 30h32c0 10-7 18-16 18S16 40 16 30Z" />
      <path d="M20 30c1-8 6-12 12-12s11 4 12 12" />
      <path d="M24 48h16" />
    </>
  ),
  clinic: (
    <>
      <circle cx="32" cy="32" r="16" />
      <path d="M32 22v20M22 32h20" />
    </>
  ),
  orphans: (
    <>
      <path d="M10 42 32 16 54 42" />
      <path d="M18 42V30h28v12" />
      <path d="M28 42v-7h8v7" />
    </>
  ),
} as const;

export function ProgrammeMark({
  name,
}: {
  name: "education" | "meals" | "clinic" | "orphans";
}) {
  return (
    <svg className="programme-mark" viewBox="0 0 64 64" aria-hidden="true">
      <g
        fill="none"
        stroke="currentColor"
        strokeWidth="2.25"
        strokeLinejoin="round"
        strokeLinecap="round"
      >
        {marks[name]}
      </g>
    </svg>
  );
}
