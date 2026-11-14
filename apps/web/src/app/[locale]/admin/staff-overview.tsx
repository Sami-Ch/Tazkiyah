import type { StaffLink, StaffLinkId } from "./staff-links";

export function StaffOverview({
  heading,
  welcome,
  name,
  intro,
  links,
  names,
  blurbs,
  stats,
  headingLevel = "h1",
}: {
  heading: string;
  headingLevel?: "h1" | "h2";
  welcome?: string;
  name?: string;
  intro: string;
  links: StaffLink[];
  names: Record<StaffLinkId, string>;
  blurbs: Record<Exclude<StaffLinkId, "home">, string>;
  stats: { label: string; value: string }[];
}) {
  const cards = links.filter(
    (link): link is StaffLink & { id: Exclude<StaffLinkId, "home"> } =>
      link.id !== "home",
  );
  return (
    <div className="staff-overview">
      <header className="public-intro">
        {headingLevel === "h1" ? (
          <h1 id="admin-title">{heading}</h1>
        ) : (
          <h2>{heading}</h2>
        )}
        <p>
          {welcome} {name ? <bdi>{name}</bdi> : null}
          {welcome || name ? ". " : null}
          {intro}
        </p>
      </header>
      {stats.length > 0 && (
        <ul className="staff-stats">
          {stats.map((stat) => (
            <li key={stat.label}>
              <bdi>{stat.value}</bdi>
              <span>{stat.label}</span>
            </li>
          ))}
        </ul>
      )}
      <ul className="staff-cards">
        {cards.map((link) => (
          <li key={link.id}>
            <a href={link.href}>
              <span>{names[link.id]}</span>
              <p>{blurbs[link.id]}</p>
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}
