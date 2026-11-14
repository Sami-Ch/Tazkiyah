"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { authRequest } from "@/components/auth-request";

type Copy = {
  displayName: string;
  profilePublic: string;
  profileLinkLabel: string;
  profileLinkUrl: string;
  addLink: string;
  removeLink: string;
  saveProfile: string;
  profileSaved: string;
  profileNameNeeded: string;
  photoLater: string;
  viewProfile: string;
  unavailable: string;
};

type Link = { label: string; url: string };

export function ProfileForm({
  locale,
  copy,
  publicRef,
  displayName,
  profilePublic,
  links,
}: {
  locale: string;
  copy: Copy;
  publicRef: string;
  displayName: string | null;
  profilePublic: boolean;
  links: Link[];
}) {
  const router = useRouter();
  const [name, setName] = useState(displayName ?? "");
  const [open, setOpen] = useState(profilePublic);
  const [rows, setRows] = useState<Link[]>(links);
  const [notice, setNotice] = useState<string>();
  const [pending, setPending] = useState(false);

  return (
    <form
      className="ui-card"
      onSubmit={(event) => {
        event.preventDefault();
        setPending(true);
        void authRequest("donor-profile", {
          displayName: name,
          profilePublic: open,
          links: rows.filter((row) => row.label.trim() || row.url.trim()),
        }).then(async (response) => {
          const body = (await response.json().catch(() => null)) as {
            code?: string;
          } | null;
          setPending(false);
          if (body?.code === "saved") {
            setNotice(copy.profileSaved);
            router.refresh();
          } else if (body?.code === "name") {
            setNotice(copy.profileNameNeeded);
          } else {
            setNotice(copy.unavailable);
          }
        });
      }}
    >
      <p>{copy.photoLater}</p>
      <label className="ui-field" htmlFor="profile-name">
        {copy.displayName}
        <input
          id="profile-name"
          value={name}
          maxLength={80}
          autoComplete="name"
          onChange={(event) => setName(event.target.value)}
        />
      </label>
      <label>
        <input
          type="checkbox"
          checked={open}
          onChange={(event) => setOpen(event.target.checked)}
        />
        {copy.profilePublic}
      </label>
      {rows.map((row, index) => (
        <div className="filter-row" key={index}>
          <label className="ui-field">
            {copy.profileLinkLabel}
            <input
              value={row.label}
              maxLength={40}
              onChange={(event) =>
                setRows(
                  rows.map((item, itemIndex) =>
                    itemIndex === index
                      ? { ...item, label: event.target.value }
                      : item,
                  ),
                )
              }
            />
          </label>
          <label className="ui-field">
            {copy.profileLinkUrl}
            <input
              value={row.url}
              inputMode="url"
              dir="ltr"
              maxLength={300}
              onChange={(event) =>
                setRows(
                  rows.map((item, itemIndex) =>
                    itemIndex === index
                      ? { ...item, url: event.target.value }
                      : item,
                  ),
                )
              }
            />
          </label>
          <button
            type="button"
            className="ui-button ui-button-quiet"
            onClick={() => setRows(rows.filter((_, itemIndex) => itemIndex !== index))}
          >
            {copy.removeLink}
          </button>
        </div>
      ))}
      {rows.length < 5 && (
        <button
          type="button"
          className="ui-button ui-button-secondary"
          onClick={() => setRows([...rows, { label: "", url: "" }])}
        >
          {copy.addLink}
        </button>
      )}
      <button className="ui-button ui-button-primary" type="submit" disabled={pending}>
        {copy.saveProfile}
      </button>
      {notice && <p role="status">{notice}</p>}
      {profilePublic && displayName && (
        <a href={`/${locale}/donors/${publicRef}`}>{copy.viewProfile}</a>
      )}
    </form>
  );
}
