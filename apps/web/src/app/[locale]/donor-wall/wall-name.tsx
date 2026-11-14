export function WallName({
  locale,
  label,
  anonymous,
  profileRef,
  trailPublic,
  publicRef,
  viewTrail,
}: {
  locale: string;
  label: string | null;
  anonymous: string;
  profileRef: string | null;
  trailPublic: boolean;
  publicRef: string;
  viewTrail: string;
}) {
  const name = label ?? anonymous;
  return (
    <>
      {profileRef ? (
        <a href={`/${locale}/donors/${profileRef}`}>
          <bdi>{name}</bdi>
        </a>
      ) : (
        <bdi>{name}</bdi>
      )}
      {trailPublic && (
        <a href={`/${locale}/trail/${publicRef}`}>{viewTrail}</a>
      )}
    </>
  );
}
