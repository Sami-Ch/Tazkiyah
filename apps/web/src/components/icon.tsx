const paths = {
  play: "M8 5v14l12-7Z",
  arrow: "M4 12h15m-6-6 6 6-6 6",
  clinic: "M9 3h6v6h6v6h-6v6H9v-6H3V9h6z",
  education:
    "M12 6v14m0-14C9.5 4 6.3 3.6 3 4.5v14c3.3-.9 6.5-.5 9 1.5m0-14C14.5 4 17.7 3.6 21 4.5v14c-3.3-.9-6.5-.5-9 1.5",
  globe:
    "M22 12a10 10 0 1 0-20 0 10 10 0 0 0 20 0ZM2 12h20M12 2c-3 3-4 6.4-4 10s1 7 4 10m0-20c3 3 4 6.4 4 10s-1 7-4 10",
  map: "M19 10c0 5-7 10-7 10s-7-5-7-10a7 7 0 1 1 14 0Zm-5 0a2 2 0 1 0-4 0 2 2 0 0 0 4 0Z",
  meals: "M3 12h18a9 9 0 0 1-18 0Zm5 9h8M9 8c0-2 2-2 2-5m3 5c0-2 2-2 2-5",
};

export function Icon({ name }: { name: keyof typeof paths }) {
  return (
    <svg
      aria-hidden="true"
      className={name === "arrow" ? "directional-icon" : undefined}
      viewBox="0 0 24 24"
      width="22"
      height="22"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d={paths[name]} />
    </svg>
  );
}
