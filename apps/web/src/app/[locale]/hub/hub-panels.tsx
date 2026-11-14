"use client";

import type { Locale } from "@tazkiyah/i18n/routing";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import { Button, TextField } from "@/design/ui";
import { AvatarMark, avatarPresets } from "./avatars";
import { hubUiCopy } from "./hub-ui-copy";

export type HubViewer = {
  role?: string;
  walkthrough?: boolean;
  step?: number;
  skipped?: string[];
  persona?: {
    display_name?: string;
    avatar?: number | null;
    bio?: string | null;
    can_rename?: boolean;
  } | null;
  public_name?: string | null;
  public_role?: string | null;
  public_bio?: { ur?: string; en?: string } | null;
};

export type PollOption = {
  id: string;
  label: string;
  votes?: number | null;
};

export type HubPoll = {
  closed?: boolean;
  multiple?: boolean;
  max_choices?: number | null;
  can_close?: boolean;
  mine?: string[];
  options?: PollOption[];
  voters?: { option: string; name: string }[] | null;
};

function noticeFor(code: string | undefined, copy: (typeof hubUiCopy)["en"]) {
  if (code === "saved" || code === "voted" || code === "posted") return copy.saved;
  if (code === "taken") return copy.taken;
  if (code === "too_soon") return copy.tooSoon;
  if (code === "rejected" || code === "contact_details") return copy.rejected;
  if (code === "submitted") return copy.submitted;
  if (code === "published") return copy.published;
  if (code === "closed") return copy.closed;
  return "";
}

export function FinishProfile({
  locale,
  viewer,
  onSaved,
}: {
  locale: Locale;
  viewer: HubViewer;
  onSaved: () => void;
}) {
  const copy = hubUiCopy[locale];
  const skipped = viewer.skipped ?? [];
  if (viewer.role !== "student") return null;
  if (!skipped.some((item) => item === "name" || item === "avatar" || item === "bio"))
    return null;
  return (
    <section className="ui-card">
      <h2>{copy.finishProfile}</h2>
      <p>{copy.finishProfileBody}</p>
      <PersonaEditor locale={locale} viewer={viewer} onSaved={onSaved} />
    </section>
  );
}

export function PersonaEditor({
  locale,
  viewer,
  onSaved,
}: {
  locale: Locale;
  viewer: HubViewer;
  onSaved: () => void;
}) {
  const copy = hubUiCopy[locale];
  const persona = viewer.persona;
  const [name, setName] = useState(persona?.display_name ?? "");
  const [bio, setBio] = useState(persona?.bio ?? "");
  const [avatar, setAvatar] = useState(persona?.avatar ?? 1);
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  if (viewer.role !== "student" || !persona) return null;

  async function save() {
    setBusy(true);
    const response = await authRequest("hub", {
      action: "persona",
      language: locale,
      name: persona?.can_rename ? name : undefined,
      bio,
      avatar,
    }).catch(() => null);
    const payload = await response?.json().catch(() => null);
    setBusy(false);
    setMessage(noticeFor(payload?.code, copy) || copy.rejected);
    if (payload?.code === "saved") onSaved();
  }

  return (
    <div className="community-form">
      <TextField
        id="persona-name"
        label={copy.penName}
        value={name}
        maxLength={24}
        disabled={!persona.can_rename}
        onChange={(event) => setName(event.target.value)}
      />
      <div className="hub-avatar-grid">
        {avatarPresets.map((preset) => (
          <button
            key={preset}
            type="button"
            className="ui-button ui-button-secondary"
            aria-pressed={avatar === preset}
            aria-label={`${copy.avatarLabel} ${preset}`}
            onClick={() => setAvatar(preset)}
          >
            <AvatarMark preset={preset} label={`${copy.avatarLabel} ${preset}`} />
          </button>
        ))}
      </div>
      <TextField
        id="persona-bio"
        label={copy.bio}
        value={bio}
        maxLength={160}
        onChange={(event) => setBio(event.target.value)}
      />
      <p>{copy.noPhoto}</p>
      <Button type="button" disabled={busy} onClick={() => void save()}>
        {copy.saveProfile}
      </Button>
      {message && <p role="status">{message}</p>}
    </div>
  );
}

export function TeacherProfileForm({
  locale,
  viewer,
  onSaved,
}: {
  locale: Locale;
  viewer: HubViewer;
  onSaved: () => void;
}) {
  const copy = hubUiCopy[locale];
  const [name, setName] = useState(viewer.public_name ?? "");
  const [role, setRole] = useState(viewer.public_role ?? "");
  const [bioUr, setBioUr] = useState(viewer.public_bio?.ur ?? "");
  const [bioEn, setBioEn] = useState(viewer.public_bio?.en ?? "");
  const [message, setMessage] = useState("");
  const [busy, setBusy] = useState(false);
  if (viewer.role !== "teacher" && viewer.role !== "admin") return null;

  async function save() {
    setBusy(true);
    const response = await authRequest("hub", {
      action: "teacher_profile",
      name,
      role,
      bioUr,
      bioEn,
    }).catch(() => null);
    const payload = await response?.json().catch(() => null);
    setBusy(false);
    setMessage(noticeFor(payload?.code, copy) || copy.rejected);
    if (payload?.code === "saved") onSaved();
  }

  return (
    <section className="ui-card community-form">
      <h2>{copy.teacherProfile}</h2>
      <p>{copy.noPhoto}</p>
      <TextField id="public-name" label={copy.teacherName} value={name} maxLength={80} onChange={(event) => setName(event.target.value)} />
      <TextField id="public-role" label={copy.teacherRole} value={role} maxLength={80} onChange={(event) => setRole(event.target.value)} />
      <TextField id="public-bio-ur" label={copy.teacherBioUr} value={bioUr} maxLength={300} onChange={(event) => setBioUr(event.target.value)} />
      <TextField id="public-bio-en" label={copy.teacherBioEn} value={bioEn} maxLength={300} onChange={(event) => setBioEn(event.target.value)} />
      <Button type="button" disabled={busy} onClick={() => void save()}>
        {copy.saveProfile}
      </Button>
      {message && <p role="status">{message}</p>}
    </section>
  );
}

export function PollCard({
  locale,
  postId,
  poll,
  onChanged,
}: {
  locale: Locale;
  postId: string;
  poll: HubPoll;
  onChanged: (message: string) => void;
}) {
  const copy = hubUiCopy[locale];
  const [chosen, setChosen] = useState<string[]>(poll.mine ?? []);
  const total = (poll.options ?? []).reduce((sum, option) => sum + (option.votes ?? 0), 0);

  async function vote() {
    const response = await authRequest("hub", { action: "vote", postId, options: chosen });
    const payload = await response.json().catch(() => null);
    onChanged(payload?.code === "voted" ? copy.voted : copy.rejected);
  }

  async function close() {
    const response = await authRequest("hub", { action: "close_poll", postId });
    const payload = await response.json().catch(() => null);
    onChanged(payload?.code === "closed" ? copy.closed : copy.rejected);
  }

  return (
    <div className="hub-poll">
      {(poll.options ?? []).map((option) => (
        <label key={option.id}>
          <input
            type={poll.multiple ? "checkbox" : "radio"}
            name={`poll-${postId}`}
            checked={chosen.includes(option.id)}
            disabled={poll.closed}
            onChange={() => {
              setChosen((current) => {
                if (!poll.multiple) return [option.id];
                return current.includes(option.id)
                  ? current.filter((id) => id !== option.id)
                  : [...current, option.id];
              });
            }}
          />
          <bdi>{option.label}</bdi>
          {typeof option.votes === "number" && (
            <span className="hub-poll-bar" aria-hidden="true">
              <span style={{ inlineSize: `${total ? Math.round((option.votes / total) * 100) : 0}%` }} />
            </span>
          )}
        </label>
      ))}
      {!poll.closed && (
        <Button type="button" onClick={() => void vote()}>
          {copy.vote}
        </Button>
      )}
      {poll.can_close && (
        <Button type="button" variant="secondary" onClick={() => void close()}>
          {copy.closePoll}
        </Button>
      )}
      {poll.voters && poll.voters.length > 0 && (
        <ul>
          {poll.voters.map((voter) => (
            <li key={`${voter.option}-${voter.name}`}>
              <bdi>{voter.name}</bdi>
              {" · "}
              <bdi>{voter.option}</bdi>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

export function VerifyForm({
  locale,
  threadId,
  posts,
  onDone,
}: {
  locale: Locale;
  threadId: string;
  posts: { id: string; author_name: string }[];
  onDone: () => void;
}) {
  const copy = hubUiCopy[locale];
  const [title, setTitle] = useState("");
  const [summary, setSummary] = useState("");
  const [body, setBody] = useState("");
  const [quotes, setQuotes] = useState<string[]>([]);
  const [message, setMessage] = useState("");

  async function send(event: FormEvent) {
    event.preventDefault();
    const response = await authRequest("hub", {
      action: "verify",
      threadId,
      language: locale,
      title,
      summary,
      body,
      quotes,
    });
    const payload = await response.json().catch(() => null);
    if (payload?.code === "posted") onDone();
    else setMessage(payload?.code === "contact_details" ? copy.rejected : copy.rejected);
  }

  return (
    <form className="community-form" onSubmit={(event) => void send(event)}>
      <h2>{copy.verify}</h2>
      <TextField id="verify-title" label={copy.verifyTitle} value={title} maxLength={150} required onChange={(event) => setTitle(event.target.value)} />
      <TextField id="verify-summary" label={copy.summary} value={summary} maxLength={300} onChange={(event) => setSummary(event.target.value)} />
      <label>
        {copy.verifyBody}
        <textarea name="body" required maxLength={20000} dir="auto" value={body} onChange={(event) => setBody(event.target.value)} />
      </label>
      <fieldset>
        <legend>{copy.quotes}</legend>
        {posts.map((post) => (
          <label key={post.id}>
            <input
              type="checkbox"
              checked={quotes.includes(post.id)}
              onChange={() =>
                setQuotes((current) =>
                  current.includes(post.id) ? current.filter((id) => id !== post.id) : [...current, post.id],
                )
              }
            />
            <bdi>{post.author_name}</bdi>
          </label>
        ))}
      </fieldset>
      <Button type="submit">{copy.verify}</Button>
      {message && <p role="status">{message}</p>}
    </form>
  );
}
