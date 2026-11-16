import type { Locale } from "@tazkiyah/i18n/routing";
import Image from "next/image";
import { getMessages } from "next-intl/server";
import type { ReactNode } from "react";
import { Icon } from "@/components/icon";
import { institute } from "@/institutes/markaz-al-azeem";
import "./sign-in.css";

/**
 * Two-column frame for every signed-out screen: a navy brand panel with the
 * institute's trust points beside the form card. Collapses to a single
 * column with a slim brand band on phones.
 */
export async function AuthFrame({
  locale,
  labelledBy,
  children,
}: {
  locale: Locale;
  labelledBy: string;
  children: ReactNode;
}) {
  const { common } = await getMessages({ locale });
  const points = [
    { icon: "shield", label: common.story.chipTraced },
    { icon: "coins", label: common.story.chipFees },
    { icon: "scale", label: common.story.chipZakat },
  ] as const;
  return (
    <section className="shell auth-layout" aria-labelledby={labelledBy}>
      <aside className="auth-panel">
        <div className="auth-ornament" aria-hidden="true" />
        <a className="auth-brand" href={`/${locale}`}>
          <Image
            src={institute.logo.small}
            alt=""
            width={56}
            height={56}
            unoptimized
          />
          <span>
            <strong>{institute.name[locale]}</strong>
            <small>{institute.mosque[locale]}</small>
          </span>
        </a>
        <p className="auth-tagline">{common.footer.tagline}</p>
        <ul className="auth-points">
          {points.map((point) => (
            <li key={point.icon}>
              <Icon name={point.icon} />
              <span>{point.label}</span>
            </li>
          ))}
        </ul>
      </aside>
      <div className="ui-card sign-in-card">{children}</div>
    </section>
  );
}
