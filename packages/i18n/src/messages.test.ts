import { expect, it } from "vitest";
import en from "../messages/en/common.json";
import ur from "../messages/ur/common.json";

type Messages = { [key: string]: string | Messages };

function messageKeys(messages: Messages): string[] {
  return Object.entries(messages).flatMap(([key, value]) =>
    typeof value === "string"
      ? [key]
      : messageKeys(value).map((childKey) => `${key}.${childKey}`),
  );
}

it("provides the same interface message keys in English and Urdu", () => {
  expect(messageKeys(ur).sort()).toEqual(messageKeys(en).sort());
});
