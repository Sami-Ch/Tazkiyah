"use client";

import { useState } from "react";
import Image from "next/image";

export function YouTubeFilm({
  videoId,
  title,
  poster,
  playLabel,
}: {
  videoId: string;
  title: string;
  poster: string;
  playLabel: string;
}) {
  const [playing, setPlaying] = useState(false);

  return playing ? (
    <iframe
      className="campus-player"
      src={`https://www.youtube-nocookie.com/embed/${encodeURIComponent(videoId)}?autoplay=1`}
      title={title}
      allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
      allowFullScreen
      referrerPolicy="strict-origin-when-cross-origin"
      ref={(frame) => frame?.focus()}
    />
  ) : (
    <button
      className="campus-player campus-play"
      type="button"
      onClick={() => setPlaying(true)}
    >
      <Image src={poster} alt="" fill unoptimized />
      <span>{playLabel}</span>
    </button>
  );
}
