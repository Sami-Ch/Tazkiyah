import { expect, it } from "vitest";
import { projectStage } from "./projects";

it("works out a project stage from its status and the money raised", () => {
  expect(
    projectStage({ status: "active", target_paisa: "100", raised_paisa: "40" }),
  ).toBe("raising");
  expect(
    projectStage({
      status: "active",
      target_paisa: "100",
      raised_paisa: "100",
    }),
  ).toBe("funded");
  expect(
    projectStage({
      status: "active",
      target_paisa: null,
      raised_paisa: "100",
    }),
  ).toBe("raising");
  expect(
    projectStage({ status: "closed", target_paisa: "100", raised_paisa: "0" }),
  ).toBe("closed");
});
