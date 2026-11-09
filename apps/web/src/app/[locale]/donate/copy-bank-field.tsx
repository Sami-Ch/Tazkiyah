"use client";

import { useState } from "react";

export function CopyBankField({
  label,
  value,
  numeric,
  copy,
  copied,
  copyError,
}: {
  label: string;
  value: string;
  numeric?: boolean;
  copy: string;
  copied: string;
  copyError: string;
}) {
  const [status, setStatus] = useState<"copied" | "error">();

  async function copyValue() {
    try {
      await navigator.clipboard.writeText(value);
      setStatus("copied");
    } catch {
      setStatus("error");
    }
  }

  return (
    <div className="donate-bank-field">
      <dt>{label}</dt>
      <dd>
        <bdi dir={numeric ? "ltr" : undefined}>{value}</bdi>
        <button
          type="button"
          className="button button-outline"
          aria-label={`${copy} ${label}`}
          onClick={copyValue}
        >
          {copy}
        </button>
      </dd>
      <dd className="donate-copy-status" role="status">
        {status === "copied" ? copied : status === "error" ? copyError : null}
      </dd>
    </div>
  );
}
