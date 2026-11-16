import type { ReactNode } from "react";
import { Icon } from "@/components/icon";
import type { StaffLink, StaffLinkId } from "./staff-links";

type CardId = Exclude<StaffLinkId, "home">;
type GroupId = "money" | "site" | "people" | "settings";

const groupOf: Record<CardId, GroupId> = {
  donations: "money",
  pledges: "money",
  reconciliation: "money",
  spending: "money",
  allNeeds: "money",
  reports: "money",
  causes: "site",
  banks: "site",
  donorLinks: "site",
  pages: "site",
  users: "people",
  classes: "people",
  moderation: "people",
  consent: "people",
  progress: "people",
  sponsorships: "people",
  audit: "settings",
  settings: "settings",
  modules: "settings",
};

const iconOf = {
  donations: "receipt",
  pledges: "clock",
  reconciliation: "bank",
  spending: "coins",
  allNeeds: "scale",
  reports: "file",
  causes: "heart",
  banks: "bank",
  donorLinks: "mail",
  pages: "file",
  users: "users",
  classes: "education",
  moderation: "chat",
  consent: "check",
  progress: "clipboard",
  sponsorships: "heart",
  audit: "clipboard",
  settings: "gear",
  modules: "grid",
} as const satisfies Record<CardId, string>;

const groupOrder: GroupId[] = ["money", "site", "people", "settings"];

export function StaffOverview({
  heading,
  welcome,
  name,
  intro,
  eyebrow,
  links,
  names,
  blurbs,
  groups,
  stats,
  actions,
  headingLevel = "h1",
}: {
  heading: string;
  headingLevel?: "h1" | "h2";
  welcome?: string;
  name?: string;
  intro: string;
  eyebrow?: string;
  links: StaffLink[];
  names: Record<StaffLinkId, string>;
  blurbs: Record<CardId, string>;
  /** Group labels; when omitted the cards render as one list. */
  groups?: Record<GroupId, string>;
  stats: { label: string; value: string }[];
  actions?: ReactNode;
}) {
  const cards = links.filter(
    (link): link is StaffLink & { id: CardId } => link.id !== "home",
  );
  const sections = groups
    ? groupOrder
        .map((group) => ({
          id: group,
          label: groups[group],
          cards: cards.filter((card) => groupOf[card.id] === group),
        }))
        .filter((section) => section.cards.length > 0)
    : [{ id: "all" as const, label: undefined, cards }];

  const renderCards = (items: typeof cards) => (
    <ul className="staff-cards">
      {items.map((link) => (
        <li key={link.id}>
          <a href={link.href}>
            <span className="staff-card-icon" aria-hidden="true">
              <Icon name={iconOf[link.id]} />
            </span>
            <span className="staff-card-title">{names[link.id]}</span>
            <p>{blurbs[link.id]}</p>
          </a>
        </li>
      ))}
    </ul>
  );

  return (
    <div className="staff-overview">
      <header className="staff-head">
        <div className="staff-head-copy">
          {eyebrow && <p className="eyebrow">{eyebrow}</p>}
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
        </div>
        {actions && <div className="staff-head-actions">{actions}</div>}
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
      {sections.map((section) =>
        section.label ? (
          <section
            key={section.id}
            className="staff-group"
            aria-labelledby={`staff-group-${section.id}`}
          >
            <h2 id={`staff-group-${section.id}`} className="staff-group-title">
              {section.label}
            </h2>
            {renderCards(section.cards)}
          </section>
        ) : (
          <div key={section.id}>{renderCards(section.cards)}</div>
        ),
      )}
    </div>
  );
}
