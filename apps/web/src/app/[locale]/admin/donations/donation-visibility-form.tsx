"use client";

import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";

export function DonationVisibilityForm({
  copy,
}: {
  copy: {
    makeAnonymous: string;
    makePrivate: string;
    visibilityReceipt: string;
    visibilitySaved: string;
    saveVisibility: string;
    results: { invalid: string; denied: string; unavailable: string };
  };
}) {
  const router = useRouter();
  const [notice, setNotice] = useState<string>();
  const [pending, setPending] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const values = new FormData(event.currentTarget);
    setPending(true);
    const response = await authRequest("donation-visibility", {
      receipt: values.get("receipt"),
      ...(values.has("anonymous") ? { anonymous: true } : {}),
      ...(values.has("trailPrivate") ? { trailPublic: false } : {}),
    });
    const body = (await response.json().catch(() => null)) as {
      code?: string;
    } | null;
    setPending(false);
    if (body?.code === "saved") {
      setNotice(copy.visibilitySaved);
      router.refresh();
      return;
    }
    setNotice(
      body?.code === "denied"
        ? copy.results.denied
        : body?.code === "invalid"
          ? copy.results.invalid
          : copy.results.unavailable,
    );
  }

  return (
    <form className="ui-card" onSubmit={(event) => void submit(event)}>
      <label className="ui-field" htmlFor="visibility-receipt">
        {copy.visibilityReceipt}
        <input id="visibility-receipt" name="receipt" required autoComplete="off" />
      </label>
      <label>
        <input type="checkbox" name="anonymous" />
        {copy.makeAnonymous}
      </label>
      <label>
        <input type="checkbox" name="trailPrivate" />
        {copy.makePrivate}
      </label>
      {notice && <p role="status">{notice}</p>}
      <button className="ui-button ui-button-secondary" type="submit" disabled={pending}>
        {copy.saveVisibility}
      </button>
    </form>
  );
}
