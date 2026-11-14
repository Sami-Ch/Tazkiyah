"use client";

import type { Locale } from "@tazkiyah/i18n/routing";
import { useEffect, useState } from "react";
import { authRequest } from "@/components/auth-request";
import { hubUiCopy } from "../hub/hub-ui-copy";

const links: Record<string, string> = {
  name: "admin/pages",
  logo: "admin/pages",
  bank: "admin/bank-accounts",
  contact: "admin/pages",
  cause: "admin/causes",
  teacher: "admin",
};

export function SetupChecklist({ locale }: { locale: Locale }) {
  const copy = hubUiCopy[locale];
  const labels: Record<string, string> = {
    name: copy.checklistName,
    logo: copy.checklistLogo,
    bank: copy.checklistBank,
    contact: copy.checklistContact,
    cause: copy.checklistCause,
    teacher: copy.checklistTeacher,
  };
  const [items, setItems] = useState<{ key: string; done: boolean }[] | null>(null);

  useEffect(() => {
    const request = new AbortController();
    void authRequest("hub", { action: "checklist" })
      .then(async (response) => {
        const payload = await response.json();
        if (request.signal.aborted || payload.code !== "ok" || !Array.isArray(payload.items))
          return;
        setItems(
          payload.items.flatMap((item: { id?: string; done?: boolean }) =>
            typeof item.id === "string" ? [{ key: item.id, done: item.done === true }] : [],
          ),
        );
      })
      .catch(() => undefined);
    return () => request.abort();
  }, []);

  if (!items || items.every((item) => item.done)) return null;

  return (
    <section className="ui-card" aria-labelledby="setup-title">
      <h2 id="setup-title">{copy.checklistTitle}</h2>
      <ul>
        {items.map((item) => (
          <li key={item.key}>
            {labels[item.key] ?? item.key}
            {": "}
            {item.done ? (
              copy.checklistDone
            ) : (
              <a href={`/${locale}/${links[item.key] ?? "admin"}`}>{copy.checklistOpen}</a>
            )}
          </li>
        ))}
      </ul>
    </section>
  );
}
