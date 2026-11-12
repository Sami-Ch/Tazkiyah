import type { Locale } from "@tazkiyah/i18n/routing";
import Image from "next/image";
import type {
  CampusFilm,
  CampusPhoto,
  PhotoCredit,
} from "@/institutes/campus-media";
import { YouTubeFilm } from "./youtube-film";

export function CampusCredit({
  credit,
  resized,
}: {
  credit: PhotoCredit;
  resized: string;
}) {
  return (
    <span className="media-credit">
      <a href={credit.source} lang="en" dir="ltr">
        {credit.creator}
      </a>
      {" · "}
      <a
        href={`https://creativecommons.org/licenses/by-sa/${credit.license}/`}
        lang="en"
        dir="ltr"
      >
        CC BY-SA {credit.license}
      </a>
      {" · "}
      {resized}
    </span>
  );
}

export function CampusPicture({
  photo,
  locale,
  lead = false,
}: {
  photo: CampusPhoto;
  locale: Locale;
  lead?: boolean;
}) {
  return (
    <picture className="campus-picture">
      {!!photo.variants?.length && (
        <source
          srcSet={photo.variants
            .map(({ src, width }) => `${src} ${width}w`)
            .join(", ")}
          sizes="(min-width: 800px) 580px, 94vw"
        />
      )}
      <Image
        src={photo.src}
        width={photo.width}
        height={photo.height}
        alt={photo.alt[locale]}
        loading={lead ? "eager" : "lazy"}
        fetchPriority={lead ? "high" : undefined}
        unoptimized
      />
    </picture>
  );
}

export function CampusMovie({
  film,
  locale,
  playLabel,
  captionLabels,
}: {
  film: CampusFilm;
  locale: Locale;
  playLabel: string;
  captionLabels: Record<Locale, string>;
}) {
  if (film.kind === "youtube") {
    return (
      <YouTubeFilm
        videoId={film.videoId}
        title={film.title[locale]}
        poster={film.poster}
        playLabel={playLabel}
      />
    );
  }

  return (
    <video
      className="campus-player"
      aria-label={film.title[locale]}
      controls
      playsInline
      preload="none"
      poster={film.poster}
    >
      <source src={film.src} type="video/mp4" />
      {(["en", "ur"] as const).map(
        (language) =>
          film.captions[language] && (
            <track
              key={language}
              kind="captions"
              src={film.captions[language]}
              srcLang={language}
              label={captionLabels[language]}
              default={language === locale}
            />
          ),
      )}
    </video>
  );
}
