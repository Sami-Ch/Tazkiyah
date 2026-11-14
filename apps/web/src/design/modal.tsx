"use client";

import { useId, useRef, type ReactNode } from "react";

/** Native dialog: focus moves inside while it is open and returns on close. */
export function Modal({
  trigger,
  title,
  closeLabel,
  children,
}: {
  trigger: string;
  title: string;
  closeLabel: string;
  children: ReactNode;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  return (
    <>
      <button
        className="ui-button ui-button-secondary"
        type="button"
        onClick={() => ref.current?.showModal()}
      >
        {trigger}
      </button>
      <dialog
        ref={ref}
        className="ui-dialog"
        aria-labelledby={titleId}
        onClick={(event) => {
          if (event.target === ref.current) ref.current?.close();
        }}
      >
        <h2 id={titleId}>{title}</h2>
        {children}
        <form method="dialog">
          <button className="ui-button ui-button-primary" type="submit">
            {closeLabel}
          </button>
        </form>
      </dialog>
    </>
  );
}
