"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { authRequest } from "@/components/auth-request";
import { Alert, Badge, Button, EmptyState, TextField } from "@/design/ui";
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

  if (!items.length) {
    return <EmptyState title={copy.empty}>{copy.intro}</EmptyState>;
  }
  return (
    <>
      <ul className="cause-grid">
        {items.map((item) => {
          const blocked =
            (item.needs_public_consent && !item.public_consent) ||
            (item.shows_face &&
              item.needs_public_consent &&
              !item.face_consent);
          return (
            <li className="ui-card" key={item.id}>
              <p>
                {copy.from} <bdi>{item.persona ?? item.real_name ?? "—"}</bdi>
                {item.class_name
                  ? ` · ${pageTranslation(item.class_name, locale)?.text ?? ""}`
                  : ""}
                {" · "}
                {copy.asks}{" "}
                {copy.scopes[item.target_scope as keyof Copy["scopes"]] ??
                  item.target_scope}
              </p>
              {item.title && <h2>{item.title}</h2>}
              {item.body && <p>{item.body}</p>}
              {item.real_name && (
                <p>
                  <bdi>{item.real_name}</bdi>
                </p>
              )}
              <div className="ui-actions">
                {item.needs_public_consent && (
                  <Badge tone={item.public_consent ? "verified" : "warning"}>
                    {item.public_consent ? copy.consent : copy.noConsent}
                  </Badge>
                )}
                {item.shows_face && (
                  <Badge tone={item.face_consent ? "verified" : "warning"}>
                    {item.face_consent ? copy.faceConsent : copy.face}
                  </Badge>
                )}
              </div>
              <form
                className="ui-form"
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
                <TextField
                  id={`moderation-note-${item.id}`}
                  name="note"
                  label={copy.note}
                  maxLength={500}
                />
                <div className="ui-actions">
                  <Button
                    type="submit"
                    name="decision"
                    value="approve"
                    disabled={busy || blocked}
                  >
                    {busy ? copy.pending : copy.approve}
                  </Button>
                  <Button
                    type="submit"
                    name="decision"
                    value="reject"
                    variant="danger"
                    disabled={busy}
                  >
                    {copy.reject}
                  </Button>
                </div>
              </form>
            </li>
          );
        })}
      </ul>
      {message && <Alert tone="success">{message}</Alert>}
      {warning && <Alert tone="danger">{warning}</Alert>}
    </>
  );
}
