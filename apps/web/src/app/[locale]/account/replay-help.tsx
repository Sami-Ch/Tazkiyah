"use client";

import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { authRequest } from "@/components/auth-request";
import { Button } from "@/design/ui";
import { hubUiCopy } from "../hub/hub-ui-copy";

export function ReplayHelp({ locale }: { locale: Locale }) {
  const copy = hubUiCopy[locale];
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  return (
    <Button
      type="button"
      variant="secondary"
      disabled={busy}
      onClick={() => {
        setBusy(true);
        void authRequest("hub", { action: "onboarding", command: "replay", step: 0 })
          .then(() => router.push(`/${locale}/hub`))
          .finally(() => setBusy(false));
      }}
    >
      {copy.replay}
    </Button>
  );
}
