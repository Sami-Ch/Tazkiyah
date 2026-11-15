const paths = {
  play: "M8 5v14l12-7Z",
  arrow: "M4 12h15m-6-6 6 6-6 6",
  chevron: "m6 9 6 6 6-6",
  check: "m5 12 5 5L20 7",
  menu: "M4 7h16M4 12h16M4 17h16",
  clinic: "M9 3h6v6h6v6h-6v6H9v-6H3V9h6z",
  education:
    "M12 6v14m0-14C9.5 4 6.3 3.6 3 4.5v14c3.3-.9 6.5-.5 9 1.5m0-14C14.5 4 17.7 3.6 21 4.5v14c-3.3-.9-6.5-.5-9 1.5",
  globe:
    "M22 12a10 10 0 1 0-20 0 10 10 0 0 0 20 0ZM2 12h20M12 2c-3 3-4 6.4-4 10s1 7 4 10m0-20c3 3 4 6.4 4 10s-1 7-4 10",
  map: "M19 10c0 5-7 10-7 10s-7-5-7-10a7 7 0 1 1 14 0Zm-5 0a2 2 0 1 0-4 0 2 2 0 0 0 4 0Z",
  meals: "M3 12h18a9 9 0 0 1-18 0Zm5 9h8M9 8c0-2 2-2 2-5m3 5c0-2 2-2 2-5",
  shield:
    "M12 3 4 6.2V12c0 4.6 3.4 8.3 8 9 4.6-.7 8-4.4 8-9V6.2L12 3Zm-3.5 9 2.5 2.5L15.5 10",
  coins:
    "M12 3C7.6 3 4 4.3 4 6v12c0 1.7 3.6 3 8 3s8-1.3 8-3V6c0-1.7-3.6-3-8-3ZM4 6c0 1.7 3.6 3 8 3s8-1.3 8-3M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3",
  scale:
    "M12 3v18m-6 0h12M12 6l6 1.5M12 6 6 7.5m0 0-3 7a3 3 0 0 0 6 0l-3-7Zm12 0-3 7a3 3 0 0 0 6 0l-3-7Z",
  quote:
    "M6 8h4a1 1 0 0 1 1 1v4a3 3 0 0 1-3 3H7m-2-7v3a1 1 0 0 0 1 1h3M14 8h4a1 1 0 0 1 1 1v4a3 3 0 0 1-3 3h-1m-2-7v3a1 1 0 0 0 1 1h3",
  clock: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Zm0-13v5l3 2",
  mail: "M4 6h16v12H4V6Zm0 1 8 6 8-6",
  phone:
    "M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2Z",
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
