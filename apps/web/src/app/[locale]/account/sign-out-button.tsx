"use client";

import { useState } from "react";
import { authRequest } from "@/components/auth-request";
import { Icon } from "@/components/icon";

export function SignOutButton({
  label,
  busyLabel,
  signInHref,
}: {
  label: string;
  busyLabel: string;
  signInHref: string;
}) {
  const [busy, setBusy] = useState(false);
  return (
    <button
      type="button"
      className="ui-button ui-button-secondary account-signout"
      disabled={busy}
      onClick={() => {
        setBusy(true);
        void authRequest("sign-out", {})
          .catch(() => undefined)
          .then(() => window.location.assign(signInHref));
      }}
    >
      <Icon name="logout" />
      {busy ? busyLabel : label}
    </button>
  );
}
