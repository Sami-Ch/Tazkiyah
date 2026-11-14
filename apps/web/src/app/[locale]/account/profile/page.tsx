import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getMessages, setRequestLocale } from "next-intl/server";
import { requireLocale } from "@/i18n/locale";
import { getDonorProfileWorkspace } from "@/server/auth";
import { ProfileForm } from "./profile-form";

export const dynamic = "force-dynamic";

export default async function AccountProfilePage({
  params,
}: PageProps<"/[locale]/account/profile">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const workspace = await getDonorProfileWorkspace(new Headers(await headers()));
  if (workspace.state === "signed-out") redirect(`/${locale}/sign-in`);
  if (workspace.state === "denied") notFound();
  const { common } = await getMessages({ locale });
  const copy = common.account;
  if (workspace.state !== "allowed") {
    return (
      <section className="shell public-stack">
        <p role="status">{copy.unavailable}</p>
      </section>
    );
  }
  return (
    <section className="shell public-stack" aria-labelledby="profile-title">
      <header className="public-intro">
        <h1 id="profile-title">{copy.publicProfile}</h1>
        <p>{copy.profileIntro}</p>
      </header>
      <ProfileForm
        locale={locale}
        copy={copy}
        publicRef={workspace.public_ref}
        displayName={workspace.display_name}
        profilePublic={workspace.profile_public}
        links={workspace.profile_links}
      />
    </section>
  );
}
