/** Eight-point star rule. Decorative only; colour comes from currentColor. */
export function StarRule() {
  return (
    <div className="star-rule" aria-hidden="true">
      <svg viewBox="0 0 88 12" width="88" height="12">
        <line
          x1="0"
          y1="6"
          x2="30"
          y2="6"
          stroke="currentColor"
          strokeWidth="1"
        />
        <path
          fill="currentColor"
          d="M44 1.1 45.7 4.3 49.1 4.7 46.5 6.9 47.2 10.2 44 8.6 40.8 10.2 41.5 6.9 38.9 4.7 42.3 4.3Z"
        />
        <line
          x1="58"
          y1="6"
          x2="88"
          y2="6"
          stroke="currentColor"
          strokeWidth="1"
        />
      </svg>
    </div>
  );
}
