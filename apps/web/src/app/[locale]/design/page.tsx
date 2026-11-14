import { setRequestLocale, getTranslations } from "next-intl/server";
import type { Metadata } from "next";
import { Modal } from "@/design/modal";
import {
  Alert,
  Amount,
  Badge,
  Button,
  CheckboxField,
  DataTable,
  EmptyState,
  ProgressBar,
  SelectField,
  Skeleton,
  TextField,
} from "@/design/ui";
import { requireLocale } from "@/i18n/locale";
import { staffLinks, type StaffLinkId } from "../admin/staff-links";
import { StaffOverview } from "../admin/staff-overview";
import { Walkthrough } from "../hub/walkthrough";
import { hubUiCopy } from "../hub/hub-ui-copy";
import "../hub/hub.css";

export const metadata: Metadata = { robots: { index: false, follow: false } };

export default async function DesignGallery({
  params,
  searchParams,
}: PageProps<"/[locale]/design">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
  const query = await searchParams;
  const sample = Array.isArray(query.sample) ? query.sample[0] : query.sample;
  const stepValue = Array.isArray(query.step) ? query.step[0] : query.step;
  const step = Number(stepValue);
  const roleValue = Array.isArray(query.role) ? query.role[0] : query.role;
  const role = roleValue === "teacher" ? "teacher" : "student";
  const copy = hubUiCopy[locale];
  if (sample === "hub") {
    return (
      <section className="shell hub-sample" aria-labelledby="sample-title">
        <h1 id="sample-title">{copy.sample}</h1>
        <article className="ui-card">
          <h2>{copy.poll}</h2>
          <p>{copy.sample}</p>
          <div className="hub-poll">
            <label>
              <input type="radio" name="sample-poll" defaultChecked />
              <bdi>{copy.sample}</bdi>
              <span className="hub-poll-bar" aria-hidden="true">
                <span style={{ inlineSize: "60%" }} />
              </span>
            </label>
          </div>
          <p>{copy.mediaGap}</p>
          <p>{copy.alumni}</p>
        </article>
      </section>
    );
  }
  if (sample === "walk") {
    return (
      <section className="shell hub-sample" aria-labelledby="sample-title">
        <h1 id="sample-title">{copy.sample}</h1>
        <Walkthrough
          locale={locale}
          role={role}
          step={Number.isInteger(step) ? step : 1}
          preview
        />
      </section>
    );
  }
  const t = await getTranslations("common");

  return (
    <section
      className="shell public-stack design-gallery"
      aria-labelledby="design-title"
    >
      <header className="public-intro">
        <h1 id="design-title">{t("navigation.menu")}</h1>
        <p>{t("public.transparencyIntro")}</p>
      </header>
      <StaffOverview
        heading={t("staffWorkspace.overviewHeading")}
        headingLevel="h2"
        intro={t("staffWorkspace.intro")}
        links={staffLinks(locale, {
          canRecordTransfers: true,
          canReconcileTransfers: true,
          canRecordSpending: true,
          canInvite: true,
          canEditPages: true,
          canManageClasses: true,
          canModerate: true,
          canMatchSponsors: true,
        })}
        names={
          {
            home: t("staffWorkspace.links.home"),
            donations: t("staffWorkspace.links.donations"),
            reconciliation: t("staffWorkspace.links.reconciliation"),
            spending: t("staffWorkspace.links.spending"),
            causes: t("staffWorkspace.links.causes"),
            banks: t("staffWorkspace.links.banks"),
            users: t("staffWorkspace.links.users"),
            audit: t("staffWorkspace.links.audit"),
            donorLinks: t("staffWorkspace.links.donorLinks"),
            pages: t("staffWorkspace.links.pages"),
            classes: t("staffWorkspace.links.classes"),
            moderation: t("staffWorkspace.links.moderation"),
            sponsorships: t("staffWorkspace.links.sponsorships"),
          } satisfies Record<StaffLinkId, string>
        }
        blurbs={{
          donations: t("staffWorkspace.blurbs.donations"),
          reconciliation: t("staffWorkspace.blurbs.reconciliation"),
          spending: t("staffWorkspace.blurbs.spending"),
          causes: t("staffWorkspace.blurbs.causes"),
          banks: t("staffWorkspace.blurbs.banks"),
          users: t("staffWorkspace.blurbs.users"),
          audit: t("staffWorkspace.blurbs.audit"),
          donorLinks: t("staffWorkspace.blurbs.donorLinks"),
          pages: t("staffWorkspace.blurbs.pages"),
          classes: t("staffWorkspace.blurbs.classes"),
          moderation: t("staffWorkspace.blurbs.moderation"),
          sponsorships: t("staffWorkspace.blurbs.sponsorships"),
        }}
        stats={[]}
      />
      <div className="design-row">
        <Button>{t("navigation.donate")}</Button>
        <Button variant="secondary">{t("public.showMore")}</Button>
        <Button variant="quiet">{t("public.read")}</Button>
        <Button variant="danger">{t("public.corrected")}</Button>
      </div>
      <TextField id="sample-name" label={t("signIn.identifier")} name="name" />
      <TextField
        id="sample-amount"
        label={t("public.raised")}
        error={t("public.notZakat")}
        inputMode="numeric"
        dir="ltr"
      />
      <SelectField id="sample-cause" label={t("public.filterCause")}>
        <option>{t("public.allNeeds")}</option>
      </SelectField>
      <CheckboxField id="sample-public" label={t("public.donorWallIntro")} />
      <div className="design-row">
        <Badge tone="zakat">{t("public.zakatOnly")}</Badge>
        <Badge tone="verified">{t("public.tabs.verified")}</Badge>
        <Badge tone="warning">{t("public.corrected")}</Badge>
      </div>
      <Alert tone="info">{t("public.donorWallIntro")}</Alert>
      <Alert tone="warning">{t("public.fallback")}</Alert>
      <Alert tone="success">{t("public.whereMoneyWent")}</Alert>
      <Alert tone="danger">{t("public.unavailable")}</Alert>
      <article className="ui-card">
        <div className="ui-pattern" aria-hidden="true" />
        <h2>{t("public.filterCause")}</h2>
        <Badge tone="zakat">{t("public.zakatOnly")}</Badge>
        <ProgressBar
          value={62}
          max={100}
          label={t("public.progress", {
            percent: "62",
            target: t("public.target"),
          })}
        />
        <Amount paisa={12_400_000n} locale={locale} />
      </article>
      <DataTable
        columns={[
          { key: "date", label: t("public.filterMonth") },
          { key: "amount", label: t("public.raised") },
          { key: "name", label: t("public.anonymous") },
        ]}
        rows={[
          {
            date: locale === "ur" ? "12 نومبر 2026" : "12 Nov 2026",
            amount: <Amount paisa={2_500_000n} locale={locale} />,
            name: <bdi>{t("public.anonymous")}</bdi>,
          },
        ]}
      />
      <EmptyState
        title={t("public.causesSoon")}
        action={<Button variant="secondary">{t("navigation.visit")}</Button>}
      >
        {t("public.causesSoon")}
      </EmptyState>
      <Skeleton />
      <Modal
        trigger={t("public.report")}
        title={t("public.report")}
        closeLabel={t("public.close")}
      >
        <p>{t("public.reportBody")}</p>
      </Modal>
    </section>
  );
}
