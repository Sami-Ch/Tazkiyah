import { routing } from "@tazkiyah/i18n/routing";
import { hasLocale } from "next-intl";
import { getRequestConfig } from "next-intl/server";

const messages = {
  en: () => import("@tazkiyah/i18n/messages/en/common.json"),
  ur: () => import("@tazkiyah/i18n/messages/ur/common.json"),
};

export default getRequestConfig(async ({ locale, requestLocale }) => {
  const requested = locale ?? (await requestLocale);
  const resolved = hasLocale(routing.locales, requested)
    ? requested
    : routing.defaultLocale;

  return {
    locale: resolved,
    messages: { common: (await messages[resolved]()).default },
  };
});
