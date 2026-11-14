import { setRequestLocale, getMessages, getTranslations } from "next-intl/server";
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
import { ConsentBoard } from "../admin/consent/consent-board";
import { ModerationQueue } from "../admin/moderation/moderation-queue";
import { ProgressBoard } from "../admin/progress/progress-board";
import { staffLinks, type StaffLinkId } from "../admin/staff-links";
import { StaffOverview } from "../admin/staff-overview";
import { SponsorshipBoard } from "../admin/sponsorships/sponsorship-board";
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
  const preview = Array.isArray(query.sample) ? query.sample[0] : query.sample;
  const stepValue = Array.isArray(query.step) ? query.step[0] : query.step;
  const step = Number(stepValue);
  const roleValue = Array.isArray(query.role) ? query.role[0] : query.role;
  const role = roleValue === "teacher" ? "teacher" : "student";
  const copy = hubUiCopy[locale];
  if (preview === "hub") {
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
  if (preview === "walk") {
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
  const { common } = await getMessages({ locale });
  const sampleId = "00000000-0000-4000-8000-000000000001";
  const sample = locale === "ur" ? "نمونہ" : "Sample";

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
          canSplitAllNeeds: true,
          canPublishReports: true,
          canInvite: true,
          canEditPages: true,
          canManageClasses: true,
          canModerate: true,
          canMatchSponsors: true,
          canRecordConsent: true,
          canPostUpdates: true,
        })}
        names={
          {
            home: t("staffWorkspace.links.home"),
            donations: t("staffWorkspace.links.donations"),
            reconciliation: t("staffWorkspace.links.reconciliation"),
            spending: t("staffWorkspace.links.spending"),
            allNeeds: t("staffWorkspace.links.allNeeds"),
            reports: t("staffWorkspace.links.reports"),
            causes: t("staffWorkspace.links.causes"),
            banks: t("staffWorkspace.links.banks"),
            users: t("staffWorkspace.links.users"),
            audit: t("staffWorkspace.links.audit"),
            donorLinks: t("staffWorkspace.links.donorLinks"),
            pages: t("staffWorkspace.links.pages"),
            classes: t("staffWorkspace.links.classes"),
            moderation: t("staffWorkspace.links.moderation"),
            consent: t("staffWorkspace.links.consent"),
            progress: t("staffWorkspace.links.progress"),
            sponsorships: t("staffWorkspace.links.sponsorships"),
          } satisfies Record<StaffLinkId, string>
        }
        blurbs={{
          donations: t("staffWorkspace.blurbs.donations"),
          reconciliation: t("staffWorkspace.blurbs.reconciliation"),
          spending: t("staffWorkspace.blurbs.spending"),
          allNeeds: t("staffWorkspace.blurbs.allNeeds"),
          reports: t("staffWorkspace.blurbs.reports"),
          causes: t("staffWorkspace.blurbs.causes"),
          banks: t("staffWorkspace.blurbs.banks"),
          users: t("staffWorkspace.blurbs.users"),
          audit: t("staffWorkspace.blurbs.audit"),
          donorLinks: t("staffWorkspace.blurbs.donorLinks"),
          pages: t("staffWorkspace.blurbs.pages"),
          classes: t("staffWorkspace.blurbs.classes"),
          moderation: t("staffWorkspace.blurbs.moderation"),
          consent: t("staffWorkspace.blurbs.consent"),
          progress: t("staffWorkspace.blurbs.progress"),
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
      <section id="staff-consent" className="staff-stack">
        <h2>{common.staffConsent.heading}</h2>
        <p>{common.staffConsent.intro}</p>
        <ConsentBoard
          locale={locale}
          copy={common.staffConsent}
          isPrincipal
          students={[
            {
              id: sampleId,
              real_name: sample,
              persona: sample,
              is_orphan: true,
            },
          ]}
          teachers={[{ id: sampleId, name: sample }]}
          sponsorships={[
            {
              id: sampleId,
              student_id: sampleId,
              persona: sample,
              real_name: sample,
            },
          ]}
          records={[
            {
              id: sampleId,
              student_id: sampleId,
              real_name: sample,
              persona: sample,
              kind: "orphan_full_profile",
              guardian_name: sample,
              relation: "principal",
              method: "in_person",
              given_on: "2026-11-14",
              notes: null,
              sponsorship_id: sampleId,
              status: "pending",
              second_signer: null,
              can_sign_principal: true,
              can_sign_second: false,
              can_assign: true,
              can_withdraw: true,
            },
          ]}
        />
      </section>
      <section id="staff-sponsorship" className="staff-stack">
        <h2>{common.staffSponsorships.heading}</h2>
        <SponsorshipBoard
          locale={locale}
          copy={common.staffSponsorships}
          isPrincipal
          unread={1}
          matches={[
            {
              id: sampleId,
              persona: sample,
              real_name: sample,
              student_id: sampleId,
              status: "active",
              started_on: "2026-11-14",
              sponsor: sample,
              consent_id: sampleId,
              consent_status: "pending",
              second_signer: null,
            },
          ]}
          orphans={[
            {
              persona_id: sampleId,
              persona: sample,
              real_name: sample,
            },
          ]}
          sponsors={[{ id: sampleId, name: sample }]}
          causes={[{ id: sampleId, title: { [locale]: sample } }]}
          teachers={[{ id: sampleId, name: sample }]}
          messages={[
            {
              id: sampleId,
              sponsorship_id: sampleId,
              persona: sample,
              direction: "to_madrasa",
              body: sample,
              language: locale,
              created_at: "2026-11-14T00:00:00.000Z",
            },
          ]}
        />
      </section>
      <section id="staff-progress" className="staff-stack">
        <h2>{common.staffProgress.heading}</h2>
        <ProgressBoard
          locale={locale}
          copy={common.staffProgress}
          isAdmin
          pupils={[
            { persona_id: sampleId, persona: sample, real_name: sample },
          ]}
          updates={[
            {
              id: sampleId,
              persona_id: sampleId,
              persona: sample,
              body: { [locale]: sample },
              published: false,
              hidden: false,
              own: false,
            },
          ]}
        />
      </section>
      <section id="staff-moderation" className="staff-stack">
        <h2>{common.staffModeration.heading}</h2>
        <ModerationQueue
          locale={locale}
          copy={common.staffModeration}
          isAdmin
          canWiden
          requests={[
            {
              id: sampleId,
              title: sample,
              body: sample,
              language: locale,
              scope: "class",
              target_scope: "madrasa",
              state: "submitted",
              hidden: false,
              persona: sample,
              class_name: { [locale]: sample },
              real_name: null,
              shows_face: false,
              needs_public_consent: false,
              public_consent: false,
              face_consent: false,
              can_approve: true,
            },
          ]}
          posts={[
            {
              id: sampleId,
              title: sample,
              body: sample,
              scope: "class",
              state: "published",
              hidden: false,
              persona: sample,
              class_name: { [locale]: sample },
              can_hide: true,
              can_remove: true,
              can_takedown: false,
            },
          ]}
          publicPosts={[
            {
              id: sampleId,
              title: sample,
              body: sample,
              scope: "public",
              state: "published",
              hidden: false,
              persona: sample,
              can_takedown: true,
            },
          ]}
          takenDown={[
            {
              id: sampleId,
              title: sample,
              body: sample,
              scope: "public",
              state: "taken_down",
              persona: sample,
              reason: sample,
              can_restore: true,
            },
          ]}
          wideners={[{ id: sampleId, name: sample, can_widen: false }]}
        />
      </section>
    </section>
  );
}
