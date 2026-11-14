import { expect, it } from "vitest";
import { receiptAmountInWords } from "./receipt-amount";

it("spells out rupees and paise in both receipt languages", () => {
  expect(receiptAmountInWords("101", "en")).toBe("one rupee and one paisa");
  expect(receiptAmountInWords("101", "ur")).toBe("ایک روپیہ اور ایک پیسہ");
  expect(receiptAmountInWords("1234567891", "en")).toBe(
    "twelve million three hundred forty-five thousand six hundred seventy-eight rupees and ninety-one paise",
  );
  expect(receiptAmountInWords("1234567891", "ur")).toBe(
    "ایک کروڑ تئیس لاکھ پینتالیس ہزار چھ سو اٹھہتر روپے اور اکیانوے پیسے",
  );
  expect(receiptAmountInWords("10000000000000", "ur")).toBe("ایک کھرب روپے");
  expect(receiptAmountInWords("900719925474099301", "en")).toBe(
    "nine quadrillion seven trillion one hundred ninety-nine billion two hundred fifty-four million seven hundred forty thousand nine hundred ninety-three rupees and one paisa",
  );
});
