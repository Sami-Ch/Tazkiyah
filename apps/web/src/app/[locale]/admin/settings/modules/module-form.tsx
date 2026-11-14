"use client";

import type common from "@tazkiyah/i18n/messages/en/common.json";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { authRequest } from "@/components/auth-request";
import { Alert, Button, CheckboxField } from "@/design/ui";
import { publicModules } from "@/institutes/public-ledger";
import type { ModuleSwitch } from "@/server/institute-workspace";

export function ModuleSwitchForm({
  modules,
  copy,
}: {
  modules: ModuleSwitch[];
  copy: typeof common.moduleSwitches;
}) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [code, setCode] = useState<string>();
  const enabled = new Set(
    modules.filter((module) => module.enabled).map((module) => module.module_name),
  );

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const fields = new FormData(event.currentTarget);
    const selected = publicModules.filter((name) => fields.has(name));
    const turningOff = [...enabled].some((name) => !selected.includes(name));
    setPending(true);
    setCode(undefined);
    try {
      const response = await authRequest("module-switches", {
        modules: selected,
        confirm: turningOff ? fields.has("confirm") : true,
      });
      const result = (await response.json()) as { code?: string };
      setCode(result.code ?? "unavailable");
      if (response.ok) router.refresh();
    } catch {
      setCode("unavailable");
    } finally {
      setPending(false);
    }
  }

  return (
    <form onSubmit={save}>
      <ul className="module-list">
        {publicModules.map((name) => (
          <li key={name}>
            <CheckboxField
              id={name}
              name={name}
              label={copy[name]}
              defaultChecked={enabled.has(name)}
            />
            <p>{copy.effects[name]}</p>
          </li>
        ))}
      </ul>
      <CheckboxField id="confirm" name="confirm" label={copy.confirm} />
      {code && (
        <Alert tone={code === "updated" ? "success" : "danger"}>
          {copy.results[code as keyof typeof copy.results] ??
            copy.results.unavailable}
        </Alert>
      )}
      <Button type="submit" disabled={pending}>
        {pending ? copy.pending : copy.save}
      </Button>
    </form>
  );
}
