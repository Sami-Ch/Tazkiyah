import type {
  ButtonHTMLAttributes,
  InputHTMLAttributes,
  ReactNode,
  SelectHTMLAttributes,
  TextareaHTMLAttributes,
} from "react";
import type { Locale } from "@tazkiyah/i18n/routing";
import { formatAmount } from "./format";

type ButtonVariant = "primary" | "secondary" | "quiet" | "danger";

export function Button({
  href,
  variant = "primary",
  children,
  type = "button",
  disabled,
  name,
  value,
  onClick,
}: {
  href?: string;
  variant?: ButtonVariant;
  children: ReactNode;
  type?: "button" | "submit";
  disabled?: boolean;
  name?: string;
  value?: string;
  onClick?: ButtonHTMLAttributes<HTMLButtonElement>["onClick"];
}) {
  const className = `ui-button ui-button-${variant}`;
  if (href) {
    return (
      <a className={className} href={href}>
        {children}
      </a>
    );
  }
  return (
    <button
      className={className}
      type={type}
      disabled={disabled}
      name={name}
      value={value}
      onClick={onClick}
    >
      {children}
    </button>
  );
}

export function TextField({
  id,
  label,
  hint,
  error,
  ...input
}: {
  id: string;
  label: string;
  hint?: string;
  error?: string;
} & InputHTMLAttributes<HTMLInputElement>) {
  const described = [hint ? `${id}-hint` : "", error ? `${id}-error` : ""]
    .filter(Boolean)
    .join(" ");
  return (
    <div className="ui-field">
      <label htmlFor={id}>{label}</label>
      <input
        id={id}
        aria-invalid={error ? true : undefined}
        aria-describedby={described || undefined}
        {...input}
      />
      {hint && (
        <p className="ui-hint" id={`${id}-hint`}>
          {hint}
        </p>
      )}
      {error && (
        <p className="ui-field-error" id={`${id}-error`}>
          {error}
        </p>
      )}
    </div>
  );
}

export function SelectField({
  id,
  label,
  hint,
  children,
  ...select
}: {
  id: string;
  label: string;
  hint?: string;
  children: ReactNode;
} & SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <div className="ui-field">
      <label htmlFor={id}>{label}</label>
      <select
        id={id}
        aria-describedby={hint ? `${id}-hint` : undefined}
        {...select}
      >
        {children}
      </select>
      {hint && (
        <p className="ui-hint" id={`${id}-hint`}>
          {hint}
        </p>
      )}
    </div>
  );
}

export function TextAreaField({
  id,
  label,
  hint,
  error,
  ...area
}: {
  id: string;
  label: string;
  hint?: string;
  error?: string;
} & TextareaHTMLAttributes<HTMLTextAreaElement>) {
  const described = [hint ? `${id}-hint` : "", error ? `${id}-error` : ""]
    .filter(Boolean)
    .join(" ");
  return (
    <div className="ui-field">
      <label htmlFor={id}>{label}</label>
      <textarea
        id={id}
        aria-invalid={error ? true : undefined}
        aria-describedby={described || undefined}
        {...area}
      />
      {hint && (
        <p className="ui-hint" id={`${id}-hint`}>
          {hint}
        </p>
      )}
      {error && (
        <p className="ui-field-error" id={`${id}-error`}>
          {error}
        </p>
      )}
    </div>
  );
}

export function CheckboxField({
  id,
  label,
  ...input
}: {
  id: string;
  label: string;
} & Omit<InputHTMLAttributes<HTMLInputElement>, "type" | "id">) {
  return (
    <label className="ui-check" htmlFor={id}>
      <input id={id} type="checkbox" {...input} />
      <span>{label}</span>
    </label>
  );
}

export function Badge({
  tone = "neutral",
  children,
}: {
  tone?: "neutral" | "zakat" | "verified" | "warning";
  children: ReactNode;
}) {
  return <span className={`ui-badge ui-badge-${tone}`}>{children}</span>;
}

export function Alert({
  tone = "info",
  children,
}: {
  tone?: "info" | "success" | "warning" | "danger";
  children: ReactNode;
}) {
  return (
    <div
      className={`ui-alert ui-alert-${tone}`}
      role={tone === "danger" ? "alert" : "status"}
    >
      {children}
    </div>
  );
}

export function EmptyState({
  title,
  children,
  action,
}: {
  title: string;
  children: ReactNode;
  action?: ReactNode;
}) {
  return (
    <div className="ui-empty">
      <div className="ui-pattern" aria-hidden="true" />
      <h2>{title}</h2>
      <p>{children}</p>
      {action}
    </div>
  );
}

export function Skeleton({ lines = 3 }: { lines?: number }) {
  return (
    <div className="ui-skeleton" aria-hidden="true">
      {Array.from({ length: lines }, (_, index) => (
        <span key={index} />
      ))}
    </div>
  );
}

export function ProgressBar({
  value,
  max,
  label,
}: {
  value: number;
  max: number;
  label: string;
}) {
  const ratio = max > 0 ? Math.min(100, Math.round((value / max) * 100)) : 0;
  return (
    <div
      className="ui-progress"
      role="progressbar"
      aria-valuemin={0}
      aria-valuemax={max}
      aria-valuenow={Math.min(value, max)}
      aria-valuetext={label}
    >
      <div className="ui-progress-track">
        <span
          className="ui-progress-fill"
          style={{ inlineSize: `${ratio}%` }}
        />
      </div>
      <p>{label}</p>
    </div>
  );
}

export function Amount({
  paisa,
  locale,
}: {
  paisa: bigint | string;
  locale: Locale;
}) {
  return (
    <bdi className="ui-amount" dir="ltr">
      {formatAmount(BigInt(paisa), locale)}
    </bdi>
  );
}

export function DataTable({
  columns,
  rows,
}: {
  columns: { key: string; label: string }[];
  rows: Record<string, ReactNode>[];
}) {
  return (
    <div className="ui-table-wrap">
      <table className="ui-table">
        <thead>
          <tr>
            {columns.map((column) => (
              <th key={column.key} scope="col">
                {column.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, index) => (
            <tr key={index}>
              {columns.map((column) => (
                <td key={column.key} data-label={column.label}>
                  {row[column.key]}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function PatternMark() {
  return <div className="ui-pattern" aria-hidden="true" />;
}
