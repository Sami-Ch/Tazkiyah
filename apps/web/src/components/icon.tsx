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
  user: "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm-7 9a7 7 0 0 1 14 0",
  users:
    "M9 12a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Zm-6 8a6 6 0 0 1 12 0M16 5a3.5 3.5 0 0 1 0 7m2 2.5a6 6 0 0 1 3 5.5",
  heart:
    "M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10Z",
  receipt: "M6 3h12v18l-3-2-3 2-3-2-3 2V3Zm3 5h6M9 12h6M9 16h4",
  file: "M7 3h7l5 5v13H7V3Zm7 0v5h5M10 13h6m-6 4h6",
  gear:
    "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm7.4-3a7.4 7.4 0 0 0-.1-1.2l2-1.5-2-3.4-2.3 1a7.5 7.5 0 0 0-2-1.2L14.6 3H9.4L9 5.7a7.5 7.5 0 0 0-2 1.2l-2.3-1-2 3.4 2 1.5a7.4 7.4 0 0 0 0 2.4l-2 1.5 2 3.4 2.3-1a7.5 7.5 0 0 0 2 1.2l.4 2.7h5.2l.4-2.7a7.5 7.5 0 0 0 2-1.2l2.3 1 2-3.4-2-1.5c.1-.4.1-.8.1-1.2Z",
  logout: "M10 4H5v16h5m4-4 4-4-4-4m4 4H9",
  chat: "M4 5h16v11H9l-5 4V5Z",
  bank: "M3 10 12 4l9 6H3Zm2 0v8m4-8v8m6-8v8m4-8v8M3 20h18",
  key: "M14 10a4 4 0 1 1 1.2 2.8L10 18H7v-3l5.8-5.8A4 4 0 0 1 14 10Z",
  grid: "M4 4h7v7H4V4Zm9 0h7v7h-7V4ZM4 13h7v7H4v-7Zm9 0h7v7h-7v-7Z",
  clipboard: "M9 4h6v3H9V4Zm6 1h3v16H6V5h3m0 7h6m-6 4h4",
};

export function Icon({ name }: { name: keyof typeof paths }) {
  return (
    <svg
      aria-hidden="true"
      className={
        name === "arrow" || name === "logout" ? "directional-icon" : undefined
      }
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
