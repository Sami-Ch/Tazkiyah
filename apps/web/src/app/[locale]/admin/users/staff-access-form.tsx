"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import type { StaffEntry, StaffRole } from "@/server/staff-directory";

type Copy = typeof common.staffDirectory;

export function StaffAccessForm({
  staff,
  copy,
}: {
  staff: StaffEntry;
  copy: Copy;
}) {
  const router = useRouter();
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function save(
    change: { nextRoles: string[] } | { nextStatus: "active" | "suspended" },
  ) {
    if (busy) return;
    setBusy(true);
    setError("");
    try {
      const response = await authRequest("staff-access", {
        id: staff.id,
        expectedRoles: staff.roles,
        expectedStatus: staff.status,
        ...change,
      });
      if (response.ok) {
        router.refresh();
      } else {
        setError(response.status === 409 ? copy.stale : copy.updateError);
      }
    } catch {
      setError(copy.updateError);
    } finally {
      setBusy(false);
    }
  }

  function saveRoles(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const roles = new FormData(event.currentTarget).getAll("role").map(String);
    if (roles.length) void save({ nextRoles: roles });
    else setError(copy.requireRole);
  }

  return (
    <details className="staff-access">
      <summary>{copy.manage}</summary>
      <form
        className="staff-access-form"
        method="post"
        onSubmit={saveRoles}
        aria-busy={busy}
      >
        <fieldset disabled={busy}>
          <legend>{copy.role}</legend>
          {(Object.keys(copy.roles) as StaffRole[]).map((role) => (
            <label key={role}>
              <input
                type="checkbox"
                name="role"
                value={role}
                defaultChecked={staff.roles.includes(role)}
              />
              {copy.roles[role]}
            </label>
          ))}
        </fieldset>
        <div className="staff-actions">
          <button className="button button-outline" disabled={busy}>
            {copy.save}
          </button>
          <button
            className="button button-outline"
            type="button"
            disabled={busy}
            onClick={() =>
              void save({
                nextStatus: staff.status === "active" ? "suspended" : "active",
              })
            }
          >
            {staff.status === "active" ? copy.suspend : copy.reactivate}
          </button>
        </div>
        {error && (
          <p className="sign-in-error" role="alert">
            {error}
          </p>
        )}
      </form>
    </details>
  );
}
