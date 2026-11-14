"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import { Alert, Button, TextField } from "@/design/ui";
import type { InstituteSettingsRow } from "@/server/institute-workspace";

const themes = ["night-and-paper", "garden-and-clay"] as const;

export function InstituteSettingsForm({
  settings,
  copy,
  locale,
  banksHref,
}: {
  settings: InstituteSettingsRow;
  copy: typeof common.instituteSettings;
  locale: Locale;
  banksHref: string;
}) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [code, setCode] = useState<string>();
  const contact = settings.contact ?? {};

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const fields = new FormData(event.currentTarget);
    const text = (name: string) => String(fields.get(name) ?? "");
    const founded = text("founded");
    setPending(true);
    setCode(undefined);
    try {
      const response = await authRequest("institute-settings", {
        name: { en: text("name-en"), ur: text("name-ur") },
        shortName: { en: text("short-en"), ur: text("short-ur") },
        parent: { en: text("parent-en"), ur: text("parent-ur") },
        address: { en: text("address-en"), ur: text("address-ur") },
        visiting: { en: text("visiting-en"), ur: text("visiting-ur") },
        phone: text("phone"),
        whatsapp: text("whatsapp"),
        email: text("email"),
        map: text("map"),
        theme: fields.get("theme"),
        founded: founded ? Number(founded) : "",
        batch: fields.get("batch"),
        principal: fields.get("principal"),
      });
      const result = (await response.json()) as { code?: string };
      setCode(result.code ?? "unavailable");
      if (response.ok) router.refresh();
    } catch {
      setCode("unavailable");
    } finally {
      setPending(false);
    }
  }

  return (
    <form className="institute-screen" lang={locale} dir={locale === "ur" ? "rtl" : "ltr"} onSubmit={save}>
      <section className="ui-card" aria-labelledby="institute-identity">
        <h2 id="institute-identity">{copy.identity}</h2>
        <div className="institute-grid">
          <TextField
            id="name-en"
            name="name-en"
            label={copy.nameEn}
            lang="en"
            dir="ltr"
            required
            maxLength={160}
            defaultValue={settings.name.en}
          />
          <TextField
            id="name-ur"
            name="name-ur"
            label={copy.nameUr}
            lang="ur"
            dir="rtl"
            required
            maxLength={160}
            defaultValue={settings.name.ur}
          />
          <TextField
            id="short-en"
            name="short-en"
            label={copy.shortEn}
            lang="en"
            dir="ltr"
            maxLength={80}
            defaultValue={settings.short_name?.en}
          />
          <TextField
            id="short-ur"
            name="short-ur"
            label={copy.shortUr}
            lang="ur"
            dir="rtl"
            maxLength={80}
            defaultValue={settings.short_name?.ur}
          />
          <TextField
            id="parent-en"
            name="parent-en"
            label={copy.parentEn}
            lang="en"
            dir="ltr"
            maxLength={160}
            defaultValue={settings.parent_body?.en}
          />
          <TextField
            id="parent-ur"
            name="parent-ur"
            label={copy.parentUr}
            lang="ur"
            dir="rtl"
            maxLength={160}
            defaultValue={settings.parent_body?.ur}
          />
          <TextField
            id="founded"
            name="founded"
            label={copy.founded}
            inputMode="numeric"
            dir="ltr"
            min={1800}
            max={2100}
            defaultValue={settings.founded_year ?? ""}
          />
        </div>
        <fieldset>
          <legend>{copy.theme}</legend>
          {themes.map((theme) => (
            <label className="ui-check" key={theme}>
              <input
                type="radio"
                name="theme"
                value={theme}
                defaultChecked={
                  (settings.theme_direction ?? "night-and-paper") === theme
                }
                required
              />
              <span>{copy.themes[theme]}</span>
            </label>
          ))}
        </fieldset>
        <p>
          <span>{copy.domain}</span>{" "}
          {settings.primary_domain ? (
            <bdi dir="ltr">{settings.primary_domain}</bdi>
          ) : (
            copy.noDomain
          )}
        </p>
        <p>{settings.logo_saved ? copy.logoSaved : copy.logoMissing}</p>
      </section>

      <section className="ui-card" aria-labelledby="institute-contact">
        <h2 id="institute-contact">{copy.contact}</h2>
        <div className="institute-grid">
          <TextField
            id="address-en"
            name="address-en"
            label={copy.addressEn}
            lang="en"
            dir="ltr"
            required
            maxLength={240}
            defaultValue={settings.address.en}
          />
          <TextField
            id="address-ur"
            name="address-ur"
            label={copy.addressUr}
            lang="ur"
            dir="rtl"
            required
            maxLength={240}
            defaultValue={settings.address.ur}
          />
          <TextField
            id="phone"
            name="phone"
            label={copy.phone}
            type="tel"
            dir="ltr"
            autoComplete="tel"
            defaultValue={contact.phone}
          />
          <TextField
            id="whatsapp"
            name="whatsapp"
            label={copy.whatsapp}
            hint={copy.whatsappHint}
            type="tel"
            dir="ltr"
            defaultValue={contact.whatsapp}
          />
          <TextField
            id="email"
            name="email"
            label={copy.email}
            type="email"
            dir="ltr"
            autoComplete="email"
            defaultValue={contact.email}
          />
          <TextField
            id="map"
            name="map"
            label={copy.map}
            hint={copy.mapHint}
            type="url"
            dir="ltr"
            defaultValue={contact.map_url}
          />
          <TextField
            id="visiting-en"
            name="visiting-en"
            label={copy.visitingEn}
            lang="en"
            dir="ltr"
            maxLength={240}
            defaultValue={contact.visiting?.en}
          />
          <TextField
            id="visiting-ur"
            name="visiting-ur"
            label={copy.visitingUr}
            lang="ur"
            dir="rtl"
            maxLength={240}
            defaultValue={contact.visiting?.ur}
          />
        </div>
      </section>

      <section className="ui-card" aria-labelledby="institute-people">
        <h2 id="institute-people">{copy.people}</h2>
        <label className="ui-field" htmlFor="principal">
          {copy.principal}
          <select
            id="principal"
            name="principal"
            defaultValue={settings.principal_user_id ?? ""}
          >
            <option value="">{copy.noPrincipal}</option>
            {settings.admins.map((admin) => (
              <option key={admin.id} value={admin.id}>
                {admin.name}
              </option>
            ))}
          </select>
        </label>
      </section>

      <section className="ui-card" aria-labelledby="institute-money">
        <h2 id="institute-money">{copy.money}</h2>
        <label className="ui-field" htmlFor="batch">
          {copy.batch}
          <select
            id="batch"
            name="batch"
            defaultValue={settings.spending_batch_mode}
          >
            <option value="daily">{copy.daily}</option>
            <option value="weekly">{copy.weekly}</option>
          </select>
        </label>
        <Button href={banksHref} variant="secondary">
          {copy.banks}
        </Button>
      </section>

      {code && (
        <Alert tone={code === "updated" ? "success" : "danger"}>
          {copy.results[code as keyof typeof copy.results] ??
            copy.results.unavailable}
        </Alert>
      )}
      <Button type="submit" disabled={pending}>
        {pending ? copy.pending : copy.save}
      </Button>
    </form>
  );
}
