import { describe, expect, it } from "vitest";
import { hubUiCopy } from "./hub-ui-copy";

describe("walkthrough copy", () => {
  it("keeps each English screen within 30 words", () => {
    for (const line of [
      ...hubUiCopy.en.studentSteps,
      ...hubUiCopy.en.teacherSteps,
    ]) {
      const words = line.trim().split(/\s+/).filter(Boolean);
      expect(words.length).toBeLessThanOrEqual(30);
    }
  });

  it("gives students eight screens and teachers four", () => {
    expect(hubUiCopy.en.studentSteps).toHaveLength(8);
    expect(hubUiCopy.ur.studentSteps).toHaveLength(8);
    expect(hubUiCopy.en.teacherSteps).toHaveLength(4);
    expect(hubUiCopy.ur.teacherSteps).toHaveLength(4);
  });
});
