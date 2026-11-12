import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getStaffDirectory } from "@/server/auth";
import { directoryFilters, staffRoles } from "@/server/staff-directory";
import { StaffAccessForm } from "./staff-access-form";
import "../../sign-in/sign-in.css";
import "./staff-directory.css";

export const dynamic = "force-dynamic";

export default async function StaffDirectoryPage({
  params,
  searchParams,
}: PageProps<"/[locale]/admin/users">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const adminHref = `/${locale}/admin`;
  const query = await searchParams;
  const filters = new URLSearchParams();
  for (const key of ["q", "role", "status", "page"]) {
    if (typeof query[key] === "string") filters.set(key, query[key]);
  }
  const directory = await getStaffDirectory(
    new Headers(await headers()),
    filters,
  );
  if (directory.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (directory.state === "enroll") redirect(adminHref);
  if (directory.state === "denied") notFound();

  const { common } = await getMessages({ locale });
  const copy = common.staffDirectory;
  const { page, role, status, search } = directoryFilters(filters);

  function pageHref(next: number) {
    const query = new URLSearchParams(filters);
    query.set("page", String(next));
    return `${adminHref}/users?${query}`;
  }

  return (
    <section
      className="shell staff-directory"
      aria-labelledby="staff-directory-title"
    >
      <a href={adminHref}>{copy.back}</a>
      <h1 id="staff-directory-title">{copy.heading}</h1>
      {directory.state === "allowed" ? (
        <>
          <form className="staff-filters sign-in-form" method="get">
            <label>
              {copy.search}
              <input
                name="q"
                defaultValue={search}
                maxLength={120}
                dir="auto"
              />
            </label>
            <label>
              {copy.role}
              <select name="role" defaultValue={role}>
                <option value="">{copy.allRoles}</option>
                {staffRoles.map((role) => (
                  <option value={role} key={role}>
                    {copy.roles[role]}
                  </option>
                ))}
              </select>
            </label>
            <label>
              {copy.status}
              <select name="status" defaultValue={status}>
                <option value="">{copy.allStatuses}</option>
                {Object.entries(copy.statuses).map(([value, label]) => (
                  <option value={value} key={value}>
                    {label}
                  </option>
                ))}
              </select>
            </label>
            <button className="button button-primary">{copy.filter}</button>
          </form>
          {directory.staff.length ? (
            <ul className="staff-list">
              {directory.staff.map((person) => (
                <li key={person.id} className="staff-entry">
                  <div className="staff-summary">
                    <div>
                      <h2>
                        <bdi>{person.name}</bdi>
                      </h2>
                      {person.email && (
                        <p>
                          <bdi>{person.email}</bdi>
                        </p>
                      )}
                    </div>
                    <div>
                      <p>{copy.statuses[person.status]}</p>
                      {person.invitation && <p>{copy[person.invitation]}</p>}
                    </div>
                  </div>
                  <ul className="staff-roles" aria-label={copy.role}>
                    {person.roles.map((role) => (
                      <li key={role}>{copy.roles[role]}</li>
                    ))}
                  </ul>
                  {person.manageable && (
                    <StaffAccessForm
                      key={[person.status, ...person.roles].join("-")}
                      staff={person}
                      copy={copy}
                    />
                  )}
                </li>
              ))}
            </ul>
          ) : (
            <p>{copy.empty}</p>
          )}
          {(page > 1 || directory.hasNext) && (
            <nav className="staff-actions" aria-label={copy.pagination}>
              {page > 1 && (
                <a className="button button-outline" href={pageHref(page - 1)}>
                  {copy.previous}
                </a>
              )}
              {directory.hasNext && (
                <a className="button button-outline" href={pageHref(page + 1)}>
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
