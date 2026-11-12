import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getAuditWorkspace } from "@/server/auth";
import { auditFilters } from "@/server/audit-log";
import "../../sign-in/sign-in.css";
import "./audit.css";

export const dynamic = "force-dynamic";

export default async function AuditPage({
  params,
  searchParams,
}: PageProps<"/[locale]/admin/audit">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const adminHref = `/${locale}/admin`;
  const rawQuery = await searchParams;
  const query = new URLSearchParams();
  for (const key of ["days", "action", "entity", "page"]) {
    if (typeof rawQuery[key] === "string") query.set(key, rawQuery[key]);
  }
  const workspace = await getAuditWorkspace(
    new Headers(await headers()),
    query,
  );
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "enroll") redirect(adminHref);
  if (workspace.state === "denied") notFound();

  const { common } = await getMessages({ locale });
  const copy = common.auditLog;
  const filters = auditFilters(query);
  const date = new Intl.DateTimeFormat(`${locale}-PK`, {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "Asia/Karachi",
  });
  function pageHref(page: number) {
    const next = new URLSearchParams(query);
    next.set("page", String(page));
    return `${adminHref}/audit?${next}`;
  }
  function valueText(value: string | boolean | null) {
    if (value === null) return "—";
    if (typeof value === "boolean") return value ? copy.yes : copy.no;
    return (copy.values as Record<string, string>)[value] ?? value;
  }

  return (
    <section className="shell audit" aria-labelledby="audit-title">
      <a href={adminHref}>{copy.back}</a>
      <h1 id="audit-title">{copy.heading}</h1>
      {workspace.state === "allowed" ? (
        <>
          <form className="sign-in-form audit-filters" method="get">
            <label>
              {copy.dateRange}
              <select name="days" defaultValue={filters.days}>
                <option value="">{copy.allDates}</option>
                <option value="1">{copy.pastDay}</option>
                <option value="7">{copy.pastWeek}</option>
                <option value="30">{copy.pastMonth}</option>
              </select>
            </label>
            <label>
              {copy.action}
              <select name="action" defaultValue={filters.action}>
                <option value="">{copy.allActions}</option>
                {filters.action &&
                  !Object.hasOwn(
                    copy.actions,
                    filters.action.replaceAll(".", ":"),
                  ) && <option value={filters.action}>{filters.action}</option>}
                {Object.entries(copy.actions).map(([code, label]) => (
                  <option key={code} value={code.replaceAll(":", ".")}>
                    {label}
                  </option>
                ))}
              </select>
            </label>
            <label>
              {copy.entity}
              <input
                name="entity"
                dir="ltr"
                defaultValue={filters.entity}
                maxLength={50}
              />
            </label>
            <button className="button button-primary">{copy.filter}</button>
          </form>
          {workspace.entries.length ? (
            <ol className="audit-list">
              {workspace.entries.map((entry) => {
                const action = (copy.actions as Record<string, string>)[
                  entry.action.replaceAll(".", ":")
                ];
                const kind =
                  (copy.actors as Record<string, string>)[entry.actor_kind] ??
                  copy.actors.system;
                const changes = Object.entries(entry.changes);
                return (
                  <li key={entry.id}>
                    <details className="audit-entry">
                      <summary>
                        <strong>{action ?? <bdi>{entry.action}</bdi>}</strong>
                        <time dateTime={entry.occurred_at}>
                          {date.format(new Date(entry.occurred_at))}
                        </time>
                        <span>{kind}</span>
                      </summary>
                      <dl className="audit-details">
                        <dt>{copy.action}</dt>
                        <dd>
                          <bdi>{entry.action}</bdi>
                        </dd>
                        <dt>{copy.entity}</dt>
                        <dd>
                          <bdi>{entry.entity}</bdi>
                        </dd>
                        {entry.actor_id && (
                          <>
                            <dt>{copy.actorId}</dt>
                            <dd>
                              <bdi>{entry.actor_id}</bdi>
                            </dd>
                          </>
                        )}
                        {entry.entity_ref && (
                          <>
                            <dt>{copy.reference}</dt>
                            <dd>
                              <bdi>{entry.entity_ref}</bdi>
                            </dd>
                          </>
                        )}
                        {!!entry.roles.length && (
                          <>
                            <dt>{copy.roles}</dt>
                            <dd>{entry.roles.map(valueText).join(", ")}</dd>
                          </>
                        )}
                      </dl>
                      {!!changes.length && (
                        <table className="audit-changes">
                          <caption>{copy.changes}</caption>
                          <thead>
                            <tr>
                              <th scope="col">{copy.field}</th>
                              <th scope="col">{copy.before}</th>
                              <th scope="col">{copy.after}</th>
                            </tr>
                          </thead>
                          <tbody>
                            {changes.map(([field, change]) => (
                              <tr key={field}>
                                <th scope="row">
                                  {(copy.fields as Record<string, string>)[
                                    field
                                  ] ?? field}
                                </th>
                                <td>{valueText(change.old)}</td>
                                <td>{valueText(change.new)}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      )}
                      {entry.hidden_fields > 0 && (
                        <p className="audit-redacted">{copy.redacted}</p>
                      )}
                    </details>
                  </li>
                );
              })}
            </ol>
          ) : (
            <p>{copy.empty}</p>
          )}
          {(filters.page > 1 || workspace.hasNext) && (
            <nav className="audit-pagination" aria-label={copy.heading}>
              {filters.page > 1 && (
                <a
                  className="button button-outline"
                  href={pageHref(filters.page - 1)}
                >
                  {copy.previous}
                </a>
              )}
              {workspace.hasNext && (
                <a
                  className="button button-outline"
                  href={pageHref(filters.page + 1)}
                >
                  {copy.next}
                </a>
              )}
            </nav>
          )}
        </>
      ) : (
        <p role="status">{common.signIn.unavailable}</p>
      )}
    </section>
  );
}
