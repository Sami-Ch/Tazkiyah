import type { NextConfig } from "next";
import createNextIntlPlugin from "next-intl/plugin";

const withNextIntl = createNextIntlPlugin();

export default withNextIntl({
  transpilePackages: ["@tazkiyah/core", "@tazkiyah/i18n"],
  poweredByHeader: false,
  devIndicators: false,
  agentRules: false,
  async redirects() {
    return [
      {
        source: "/:locale(en|ur)/login",
        destination: "/:locale/sign-in",
        permanent: true,
      },
    ];
  },
  async headers() {
    const headers = [
      { key: "Cache-Control", value: "private, no-store" },
      { key: "Referrer-Policy", value: "no-referrer" },
      { key: "X-Robots-Tag", value: "noindex, nofollow" },
    ];
    return [
      {
        source:
          "/:locale(en|ur)/:page(sign-in|signup|forgot-password|reset-password|account)",
        headers,
      },
      { source: "/:locale(en|ur)/trail", headers },
      { source: "/:locale(en|ur)/admin/donor-links", headers },
      { source: "/api/auth/:endpoint(donor-trail|donor-link)", headers },
      {
        source: "/api/auth/:endpoint(verify-email|reset-password)/:token?",
        headers,
      },
    ];
  },
} satisfies NextConfig);
