"use client";

import { useEffect, useRef, useState } from "react";

/** Counts up when the figure scrolls into view. The accessible name stays the final value. */
export function CountUp({ value, label }: { value: number; label: string }) {
  const ref = useRef<HTMLElement>(null);
  const [text, setText] = useState(label);

  useEffect(() => {
    const node = ref.current;
    if (!node) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    let frame = 0;
    const observer = new IntersectionObserver(
      (entries) => {
        if (!entries.some((entry) => entry.isIntersecting)) return;
        observer.disconnect();
        const start = performance.now();
        const run = (now: number) => {
          const progress = Math.min(1, (now - start) / 800);
          const eased = 1 - (1 - progress) ** 3;
          setText(String(Math.round(value * eased)));
          if (progress < 1) frame = requestAnimationFrame(run);
          else setText(label);
        };
        frame = requestAnimationFrame(run);
      },
      { threshold: 0.45 },
    );
    observer.observe(node);
    return () => {
      observer.disconnect();
      cancelAnimationFrame(frame);
    };
  }, [label, value]);

  return (
    <bdi ref={ref} aria-label={label}>
      {text}
    </bdi>
  );
}
