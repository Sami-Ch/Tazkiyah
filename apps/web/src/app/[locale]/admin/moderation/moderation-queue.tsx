"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { authRequest } from "@/components/auth-request";
import { pageTranslation } from "@/institutes/site-pages";
import type { ModerationItem } from "@/server/moderation";

type Copy = typeof common.staffModeration;

export function ModerationQueue({
  locale,
  copy,
  items,
}: {
  locale: Locale;
  copy: Copy;
  items: ModerationItem[];
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [warning, setWarning] = useState("");

  async function decide(
    postId: string,
    action: "approve" | "reject",
    note: string,
  ) {
    setBusy(true);
    setMessage("");
    setWarning("");
    const response = await authRequest("moderation", { postId, action, note });
    const result = (await response.json().catch(() => null)) as {
      code?: keyof Copy;
    } | null;
    setBusy(false);
    const code = result?.code;
    if (code === "approved") setMessage(copy.approved);
    else if (code === "rejected") setMessage(copy.rejected);
    else if (code && typeof copy[code] === "string")
      setWarning(copy[code] as string);
    else setWarning(copy.unavailable);
    router.refresh();
  }

  if (!items.length) return <p>{copy.empty}</p>;
  return (
    <>
      <ul className="staff-rows">
        {items.map((item) => {
          const blocked =
            (item.needs_public_consent && !item.public_consent) ||
            (item.shows_face &&
              item.needs_public_consent &&
              !item.face_consent);
          return (
            <li className="staff-panel" key={item.id}>
              <p className="staff-meta">
                <span>
                  {copy.from} <bdi>{item.persona ?? item.real_name ?? "—"}</bdi>
                </span>
                {item.class_name && (
                  <span>{pageTranslation(item.class_name, locale)?.text}</span>
                )}
                <span>
                  {copy.asks}{" "}
                  {copy.scopes[item.target_scope as keyof Copy["scopes"]] ??
                    item.target_scope}
                </span>
              </p>
              {item.title && <h2>{item.title}</h2>}
              {item.body && <p>{item.body}</p>}
              {item.real_name && (
                <p>
                  <bdi>{item.real_name}</bdi>
                </p>
              )}
              <p className="staff-meta">
                {item.needs_public_consent && (
                  <span
                    className={
                      item.public_consent
                        ? "staff-flag"
                        : "staff-flag staff-flag-stop"
                    }
                  >
                    {item.public_consent ? copy.consent : copy.noConsent}
                  </span>
                )}
                {item.shows_face && (
                  <span
                    className={
                      item.face_consent
                        ? "staff-flag"
                        : "staff-flag staff-flag-stop"
                    }
                  >
                    {item.face_consent ? copy.faceConsent : copy.face}
                  </span>
                )}
              </p>
              <form
                className="staff-fields"
                onSubmit={(event) => {
                  event.preventDefault();
                  const data = new FormData(event.currentTarget);
                  const submitter = (event.nativeEvent as SubmitEvent)
                    .submitter;
                  const action = submitter?.getAttribute("value");
                  if (action !== "approve" && action !== "reject") return;
                  void decide(item.id, action, String(data.get("note") ?? ""));
                }}
              >
                <label className="staff-span">
                  {copy.note}
                  <input name="note" maxLength={500} />
                </label>
                <button
                  className="button button-primary"
                  type="submit"
                  name="decision"
                  value="approve"
                  disabled={busy || blocked}
                >
                  {busy ? copy.pending : copy.approve}
                </button>
                <button
                  className="button button-outline"
                  type="submit"
                  name="decision"
                  value="reject"
                  disabled={busy}
                >
                  {copy.reject}
                </button>
              </form>
            </li>
          );
        })}
      </ul>
      {message && (
        <p className="staff-success" role="status">
          {message}
        </p>
      )}
      {warning && (
        <p className="staff-warning" role="alert">
          {warning}
        </p>
      )}
    </>
  );
}
