"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { authRequest } from "@/components/auth-request";
import { Alert, Badge, Button, EmptyState, TextField } from "@/design/ui";
import { pageTranslation } from "@/institutes/site-pages";
import type {
  ModerationItem,
  ModerationPost,
  ScopeWidener,
} from "@/server/moderation";

type Copy = typeof common.staffModeration;
type Tab = "requests" | "posts" | "public" | "removed" | "widen";
const states = ["draft", "submitted", "approved", "published", "taken_down"] as const;

export function ModerationQueue({
  locale,
  copy,
  isAdmin,
  canWiden,
  requests,
  posts,
  publicPosts,
  takenDown,
  wideners,
}: {
  locale: Locale;
  copy: Copy;
  isAdmin: boolean;
  canWiden: boolean;
  requests: ModerationItem[];
  posts: ModerationPost[];
  publicPosts: ModerationPost[];
  takenDown: ModerationPost[];
  wideners: ScopeWidener[];
}) {
  const router = useRouter();
  const [tab, setTab] = useState<Tab>("requests");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [warning, setWarning] = useState("");

  async function act(body: Record<string, unknown>) {
    setBusy(true);
    setMessage("");
    setWarning("");
    const response = await authRequest("moderation", body);
    const result = (await response.json().catch(() => null)) as {
      code?: string;
    } | null;
    setBusy(false);
    const code = result?.code;
    const text =
      code && code in copy && typeof copy[code as keyof Copy] === "string"
        ? (copy[code as keyof Copy] as string)
        : "";
    if (
      code === "approved" ||
      code === "rejected" ||
      code === "hide" ||
      code === "unhide" ||
      code === "remove" ||
      code === "takedown" ||
      code === "restore" ||
      code === "saved"
    )
      setMessage(text || copy.saved);
    else if (text) setWarning(text);
    else setWarning(copy.unavailable);
    router.refresh();
  }

  const tabs: { id: Tab; label: string }[] = [
    { id: "requests", label: copy.tabs.requests },
    { id: "posts", label: copy.tabs.posts },
    { id: "public", label: copy.tabs.public },
    { id: "removed", label: copy.tabs.removed },
    ...(isAdmin ? [{ id: "widen" as const, label: copy.tabs.widen }] : []),
  ];

  return (
    <>
      <div className="filter-row" role="tablist" aria-label={copy.heading}>
        {tabs.map((item) => (
          <button
            key={item.id}
            type="button"
            role="tab"
            aria-selected={tab === item.id}
            onClick={() => setTab(item.id)}
          >
            {item.label}
          </button>
        ))}
      </div>
      {tab === "requests" &&
        (requests.length ? (
          <ul className="cause-grid">
            {requests.map((item) => (
              <li className="ui-card" key={item.id}>
                <StateLine copy={copy} state={item.state} />
                <p>
                  {copy.from} <bdi>{item.persona ?? item.real_name ?? "—"}</bdi>
                  {item.class_name
                    ? ` · ${pageTranslation(item.class_name, locale)?.text ?? ""}`
                    : ""}
                  {" · "}
                  {copy.asks}{" "}
                  {item.target_scope === "madrasa"
                    ? copy.widenAsk
                    : (copy.scopes[item.target_scope as keyof Copy["scopes"]] ??
                      item.target_scope)}
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
                  {item.target_scope === "madrasa" && !canWiden && (
                    <Badge tone="warning">{copy.widenBlocked}</Badge>
                  )}
                </div>
                <ActionForm
                  id={item.id}
                  copy={copy}
                  busy={busy}
                  approveLabel={
                    item.target_scope === "madrasa" ? copy.widen : copy.approve
                  }
                  approveDisabled={
                    busy ||
                    !item.can_approve ||
                    (item.needs_public_consent && !item.public_consent) ||
                    (item.shows_face &&
                      item.needs_public_consent &&
                      !item.face_consent)
                  }
                  onAct={act}
                />
              </li>
            ))}
          </ul>
        ) : (
          <EmptyState title={copy.empty}>{copy.intro}</EmptyState>
        ))}
      {tab === "posts" && (
        <PostList
          copy={copy}
          locale={locale}
          posts={posts}
          busy={busy}
          empty={copy.noPosts}
          onAct={act}
        />
      )}
      {tab === "public" && (
        <PostList
          copy={copy}
          locale={locale}
          posts={publicPosts}
          busy={busy}
          empty={copy.noPublic}
          onAct={act}
        />
      )}
      {tab === "removed" && (
        <PostList
          copy={copy}
          locale={locale}
          posts={takenDown}
          busy={busy}
          empty={copy.noRemoved}
          onAct={act}
        />
      )}
      {tab === "widen" && isAdmin && (
        <section className="ui-card" aria-labelledby="widener-title">
          <h2 id="widener-title">{copy.wideners}</h2>
          <p>{copy.widenerIntro}</p>
          {wideners.length ? (
            <ul className="cause-grid">
              {wideners.map((teacher) => (
                <li key={teacher.id}>
                  <label className="ui-check">
                    <input
                      type="checkbox"
                      checked={teacher.can_widen}
                      disabled={busy}
                      onChange={(event) =>
                        void act({
                          action: "widen",
                          teacherId: teacher.id,
                          enabled: event.target.checked,
                        })
                      }
                    />
                    <span>
                      <bdi>{teacher.name}</bdi>
                    </span>
                  </label>
                </li>
              ))}
            </ul>
          ) : (
            <EmptyState title={copy.noWideners}>{copy.widenerIntro}</EmptyState>
          )}
        </section>
      )}
      {message && <Alert tone="success">{message}</Alert>}
      {warning && <Alert tone="danger">{warning}</Alert>}
    </>
  );
}

function StateLine({ copy, state }: { copy: Copy; state: string }) {
  return (
    <ol className="state-row">
      {states.map((step) => (
        <li key={step}>
          <Badge tone={step === state ? "verified" : "neutral"}>
            {copy.states[step]}
          </Badge>
        </li>
      ))}
    </ol>
  );
}

function ActionForm({
  id,
  copy,
  busy,
  approveLabel,
  approveDisabled,
  onAct,
}: {
  id: string;
  copy: Copy;
  busy: boolean;
  approveLabel: string;
  approveDisabled: boolean;
  onAct: (body: Record<string, unknown>) => Promise<void>;
}) {
  return (
    <form
      className="ui-form"
      onSubmit={(event) => {
        event.preventDefault();
        const data = new FormData(event.currentTarget);
        const submitter = (event.nativeEvent as SubmitEvent).submitter;
        const action = submitter?.getAttribute("value");
        if (action !== "approve" && action !== "reject") return;
        void onAct({
          postId: id,
          action,
          note: String(data.get("note") ?? ""),
        });
      }}
    >
      <TextField id={`moderation-note-${id}`} name="note" label={copy.note} maxLength={500} />
      <div className="ui-actions">
        <Button type="submit" name="decision" value="approve" disabled={approveDisabled}>
          {busy ? copy.pending : approveLabel}
        </Button>
        <Button type="submit" name="decision" value="reject" variant="danger" disabled={busy}>
          {copy.reject}
        </Button>
      </div>
    </form>
  );
}

function PostList({
  copy,
  locale,
  posts,
  busy,
  empty,
  onAct,
}: {
  copy: Copy;
  locale: Locale;
  posts: ModerationPost[];
  busy: boolean;
  empty: string;
  onAct: (body: Record<string, unknown>) => Promise<void>;
}) {
  if (!posts.length) return <EmptyState title={empty}>{copy.postIntro}</EmptyState>;
  return (
    <ul className="cause-grid">
      {posts.map((post) => (
        <li className="ui-card" key={post.id}>
          <StateLine copy={copy} state={post.state} />
          <p>
            {copy.from} <bdi>{post.persona ?? "—"}</bdi>
            {post.class_name
              ? ` · ${pageTranslation(post.class_name, locale)?.text ?? ""}`
              : ""}
            {" · "}
            {copy.scopes[post.scope as keyof Copy["scopes"]] ?? post.scope}
            {post.hidden ? ` · ${copy.hidden}` : ""}
          </p>
          {post.title && <h2>{post.title}</h2>}
          {post.body && <p>{post.body}</p>}
          {post.reason && (
            <p>
              {copy.reason}: {post.reason}
            </p>
          )}
          <form
            className="ui-form"
            onSubmit={(event) => {
              event.preventDefault();
              const data = new FormData(event.currentTarget);
              const submitter = (event.nativeEvent as SubmitEvent).submitter;
              const action = submitter?.getAttribute("value");
              if (
                action !== "hide" &&
                action !== "unhide" &&
                action !== "remove" &&
                action !== "takedown" &&
                action !== "restore"
              )
                return;
              void onAct({
                postId: post.id,
                action,
                note: String(data.get("note") ?? ""),
              });
            }}
          >
            {(post.can_hide || post.can_remove || post.can_takedown) && (
              <TextField id={`reason-${post.id}`} name="note" label={copy.reason} required maxLength={500} />
            )}
            <div className="ui-actions">
              {post.can_hide && (
                <Button type="submit" name="decision" value="hide" variant="secondary" disabled={busy}>
                  {copy.hide}
                </Button>
              )}
              {post.can_unhide && (
                <Button type="submit" name="decision" value="unhide" variant="secondary" disabled={busy}>
                  {copy.unhide}
                </Button>
              )}
              {post.can_remove && (
                <Button type="submit" name="decision" value="remove" variant="danger" disabled={busy}>
                  {copy.remove}
                </Button>
              )}
              {post.can_takedown && (
                <Button type="submit" name="decision" value="takedown" variant="danger" disabled={busy}>
                  {copy.takedown}
                </Button>
              )}
              {post.can_restore && (
                <Button type="submit" name="decision" value="restore" disabled={busy}>
                  {copy.restore}
                </Button>
              )}
            </div>
          </form>
        </li>
      ))}
    </ul>
  );
}
