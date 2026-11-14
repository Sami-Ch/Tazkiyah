"use client";

import type { Locale } from "@tazkiyah/i18n/routing";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { authRequest } from "@/components/auth-request";
import { Button, TextField } from "@/design/ui";
import { AvatarMark, avatarPresets } from "./avatars";
import { hubUiCopy } from "./hub-ui-copy";

type Role = "student" | "teacher";

export function Walkthrough({
  locale,
  role,
  step,
  preview = false,
  onDone,
}: {
  locale: Locale;
  role: Role;
  step: number;
  preview?: boolean;
  onDone?: () => void;
}) {
  const copy = hubUiCopy[locale];
  const router = useRouter();
  const lines = role === "student" ? copy.studentSteps : copy.teacherSteps;
  const total = lines.length;
  const [current, setCurrent] = useState(Math.min(total, Math.max(1, step)));
  const [name, setName] = useState("");
  const [bio, setBio] = useState("");
  const [avatar, setAvatar] = useState(1);
  const [salaam, setSalaam] = useState(copy.salaam);
  const [names, setNames] = useState<string[]>([]);
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const text = lines[current - 1] ?? lines[0];

  async function send(command: string, value = "", chosen?: number) {
    if (preview) {
      if (command === "back") setCurrent((value) => Math.max(1, value - 1));
      else if (command === "finish" || current >= total) onDone?.();
      else setCurrent((value) => Math.min(total, value + 1));
      return;
    }
    if (busy) return;
    setBusy(true);
    setNotice("");
    const response = await authRequest("hub", {
      action: "onboarding",
      command,
      step: current,
      value,
      avatar: chosen,
    }).catch(() => null);
    const payload = await response?.json().catch(() => null);
    setBusy(false);
    if (payload?.code !== "ok") {
      setNotice(
        payload?.code === "taken"
          ? copy.taken
          : payload?.code === "too_soon"
            ? copy.tooSoon
            : payload?.code === "rejected" || payload?.code === "contact_details"
              ? copy.rejected
              : copy.saved,
      );
      if (payload?.code !== "rejected" && payload?.code !== "taken" && payload?.code !== "too_soon" && payload?.code !== "contact_details")
        setNotice("");
      return;
    }
    if (Array.isArray(payload.names)) {
      setNames(payload.names.filter((item: unknown) => typeof item === "string"));
      return;
    }
    if (payload.onboarded) {
      onDone?.();
      return;
    }
    if (command === "language" && (value === "ur" || value === "en") && value !== locale) {
      router.push(`/${value}/hub`);
    }
    if (typeof payload.step === "number") setCurrent(payload.step);
  }

  return (
    <section className="ui-card hub-walk" aria-labelledby="walk-title">
      <div className="hub-walk-progress" aria-hidden="true">
        {lines.map((_, index) => (
          <span data-done={index < current ? "true" : "false"} key={index} />
        ))}
      </div>
      <p id="walk-title">{text}</p>
      {role === "student" && current === 2 && (
        <>
          <TextField
            id="pen-name"
            label={copy.penName}
            value={name}
            maxLength={24}
            onChange={(event) => setName(event.target.value)}
          />
          <Button type="button" variant="secondary" disabled={busy} onClick={() => void send("suggest")}>
            {copy.suggest}
          </Button>
          {names.length > 0 && (
            <div className="hub-actions">
              {names.map((suggestion) => (
                <Button key={suggestion} type="button" variant="secondary" onClick={() => setName(suggestion)}>
                  <bdi>{suggestion}</bdi>
                </Button>
              ))}
            </div>
          )}
        </>
      )}
      {role === "student" && current === 3 && (
        <div className="hub-avatar-grid">
          {avatarPresets.map((preset) => (
            <button
              key={preset}
              type="button"
              className="ui-button ui-button-secondary"
              aria-pressed={avatar === preset}
              onClick={() => setAvatar(preset)}
            >
              <AvatarMark preset={preset} label={`${copy.avatarLabel} ${preset}`} />
            </button>
          ))}
        </div>
      )}
      {role === "student" && current === 4 && (
        <TextField
          id="walk-bio"
          label={copy.bio}
          value={bio}
          maxLength={160}
          onChange={(event) => setBio(event.target.value)}
        />
      )}
      {role === "student" && current === 7 && (
        <TextField
          id="walk-salaam"
          label={copy.postSalaam}
          value={salaam}
          maxLength={1000}
          onChange={(event) => setSalaam(event.target.value)}
        />
      )}
      <div className="hub-actions">
        {current > 1 && (
          <Button type="button" variant="secondary" disabled={busy} onClick={() => void send("back")}>
            {copy.back}
          </Button>
        )}
        {current === 1 ? (
          <>
            <Button type="button" disabled={busy} onClick={() => void send("language", "ur")}>
              {locale === "ur" ? "اردو" : "Urdu"}
            </Button>
            <Button type="button" variant="secondary" disabled={busy} onClick={() => void send("language", "en")}>
              {locale === "ur" ? "انگریزی" : "English"}
            </Button>
          </>
        ) : (
          <Button
            type="button"
            disabled={busy}
            onClick={() => {
              if (role === "student" && current === 2) void send("name", name);
              else if (role === "student" && current === 3) void send("avatar", "", avatar);
              else if (role === "student" && current === 4)
                void send("bio", `${locale}:${bio}`);
              else if (role === "student" && current === 5) void send("next");
              else if (role === "student" && current === 7)
                void send("post", salaam, locale === "en" ? 1 : 0);
              else if (current >= total) void send("finish");
              else void send("next");
            }}
          >
            {current === 5 ? copy.understand : current >= total ? copy.finish : copy.next}
          </Button>
        )}
        {current < total && current !== 5 && (
          <Button type="button" variant="secondary" disabled={busy} onClick={() => void send("skip")}>
            {copy.skip}
          </Button>
        )}
      </div>
      {notice && <p role="status">{notice}</p>}
    </section>
  );
}
