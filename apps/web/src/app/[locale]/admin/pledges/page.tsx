import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { formatDate } from "@/design/format";
import { Amount, EmptyState } from "@/design/ui";
import { requireLocale } from "@/i18n/locale";
import { pageTranslation } from "@/institutes/site-pages";
import { getPledgeWorkspace } from "@/server/auth";
import "../settings/settings.css";

export const dynamic = "force-dynamic";

export default async function ExpectedPledgesPage({
  params,
}: PageProps<"/[locale]/admin/pledges">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const admin = `/${locale}/admin`;
  const workspace = await getPledgeWorkspace(new Headers(await headers()));
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "enroll") redirect(admin);
  if (workspace.state === "denied") notFound();
  const { common } = await getMessages({ locale });
  const copy = common.expectedPledges;

  return (
    <section className="staff-stack institute-screen" aria-labelledby="expected-pledges-title">
      <a href={admin}>{copy.back}</a>
      <h1 id="expected-pledges-title">{copy.heading}</h1>
      <p>{copy.intro}</p>
      {workspace.state !== "allowed" ? (
        <p role="status">{common.signIn.unavailable}</p>
      ) : workspace.pledges.length === 0 ? (
        <EmptyState title={copy.heading}>{copy.empty}</EmptyState>
      ) : (
        <ul className="pledge-list">
          {workspace.pledges.map((pledge) => {
            const cause = pageTranslation(pledge.cause_title ?? undefined, locale);
            return (
              <li className="pledge-card" key={pledge.id}>
                <h2>{pledge.donor_label ?? copy.noName}</h2>
                <p>
                  {pledge.is_anonymous ? copy.anonymous : copy.named}
                </p>
                <dl>
                  <div>
                    <dt>{copy.cause}</dt>
                    <dd lang={cause?.language} dir={cause?.language === "ur" ? "rtl" : "ltr"}>
                      {cause?.text ?? copy.allNeeds}
                    </dd>
                  </div>
                  <div>
                    <dt>{copy.amount}</dt>
                    <dd>
                      <Amount paisa={pledge.amount_paisa} locale={locale} />
                    </dd>
                  </div>
                  <div>
                    <dt>{copy.frequency}</dt>
                    <dd>
                      {pledge.frequency === "yearly" ? copy.yearly : copy.monthly}
                      {" · "}
                      {copy.types[pledge.donation_type]}
                    </dd>
                  </div>
                  <div>
                    <dt>{copy.period}</dt>
                    <dd>
                      <time dateTime={pledge.period_start}>
                        {formatDate(pledge.period_start, locale)}
                      </time>
                      {" – "}
                      <time dateTime={pledge.period_end}>
                        {formatDate(pledge.period_end, locale)}
                      </time>
                    </dd>
                  </div>
                </dl>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
