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

export const metadata: Metadata = { robots: { index: false, follow: false } };

export default async function DesignGallery({
  params,
}: PageProps<"/[locale]/design">) {
  const locale = requireLocale((await params).locale);
  setRequestLocale(locale);
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
